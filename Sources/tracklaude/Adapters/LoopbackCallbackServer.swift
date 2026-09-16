import Foundation
import Network
import TracklaudeCore

/// Production CallbackListener: a one-shot HTTP listener on the loopback interface only.
///
/// Binds both 127.0.0.1 and ::1 (whichever `localhost` resolves to in the browser), on the
/// first free port from `OAuthConfig.callbackPorts`. Listens only between `start` and the
/// first accepted callback (or `cancel`). The socket layer never sees the state or the code:
/// it hands request targets to `OAuthCallback.parse` and writes back whatever reply that verdict earns.
actor LoopbackCallbackServer: CallbackListener {
    private var expectedState = ""
    private var sockets: LoopbackSockets?
    private var pending: CheckedContinuation<String, any Error>?
    /// Why: the browser can redirect before `awaitCode` has installed its continuation
    /// (the flow opens the browser first). The verdict is parked here until it is asked for.
    private var outcome: Result<String, any Error>?
    private var lastBindError: (any Error)?

    func start(expectedState: String) async throws -> UInt16 {
        self.expectedState = expectedState
        outcome = nil
        for port in OAuthConfig.callbackPorts {
            let candidate = LoopbackSockets(port: port) { [weak self] target in
                await self?.reply(to: target) ?? .notFound
            }
            do {
                try await candidate.bind()
                sockets = candidate
                return port
            } catch {
                candidate.stop()
                lastBindError = error
            }
        }
        throw SignInError.noCallbackPort(underlying: lastBindError)
    }

    func awaitCode() async throws -> String {
        if let outcome { return try outcome.get() }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pending = continuation
                // Why: `onCancel` fires asynchronously, so a cancellation that landed before
                // this continuation existed would otherwise be missed and the wait would hang.
                if Task.isCancelled { cancel() }
            }
        } onCancel: {
            Task { await self.cancel() }
        }
    }

    func cancel() {
        finish(with: .failure(CancellationError()))
    }

    private func reply(to requestTarget: String) -> LoopbackSockets.Reply {
        switch OAuthCallback.parse(requestTarget: requestTarget, expectedState: expectedState) {
        case .accepted(let code):
            finish(with: .success(code))
            return .signedIn
        case .rejected(.denied(let reason)):
            finish(with: .failure(SignInError.denied(reason)))
            return .cancelled
        case .rejected:
            return .notFound
        }
    }

    private func finish(with result: Result<String, any Error>) {
        sockets?.stop()
        sockets = nil
        if let pending {
            pending.resume(with: result)
            self.pending = nil
        } else if outcome == nil {
            outcome = result
        }
    }
}

enum SignInError: Error, LocalizedError {
    case noCallbackPort(underlying: (any Error)?)
    case denied(String)

    var errorDescription: String? {
        switch self {
        case .noCallbackPort(let underlying):
            let ports = OAuthConfig.callbackPorts.map(String.init).joined(separator: " or ")
            let detail = underlying.map { " (\($0.localizedDescription))" } ?? ""
            return "Could not listen on localhost port \(ports) for the browser's reply\(detail)."
        case .denied(let reason):
            return "Anthropic did not approve the sign-in (\(reason))."
        }
    }
}

/// The Network-framework half: two listeners, one per loopback address, sharing a port.
/// NW objects stay on this class's serial queue; only request-target Strings cross to the actor.
private final class LoopbackSockets: @unchecked Sendable {
    struct Reply {
        let status: Int
        let reason: String
        let body: String

        static let signedIn = Reply(status: 200, reason: "OK", body: "Signed in — you can close this tab.")
        static let cancelled = Reply(status: 200, reason: "OK", body: "Sign-in was cancelled. You can close this tab.")
        static let notFound = Reply(status: 404, reason: "Not Found", body: "Not found.")
        static let badRequest = Reply(status: 400, reason: "Bad Request", body: "Bad request.")

        var wire: Data {
            let html = "<!doctype html><meta charset=utf-8><title>tracklaude</title><p>\(body)"
            let head = "HTTP/1.1 \(status) \(reason)\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(html.utf8.count)\r\nConnection: close\r\n\r\n"
            return Data((head + html).utf8)
        }
    }

    private static let loopbackHosts: [NWEndpoint.Host] = ["127.0.0.1", "::1"]
    private static let maxRequestBytes = 8192

    private let port: NWEndpoint.Port
    private let handler: @Sendable (String) async -> Reply
    private let queue = DispatchQueue(label: "tracklaude.oauth-callback")
    private var listeners: [NWListener] = []

    init(port: UInt16, handler: @escaping @Sendable (String) async -> Reply) {
        self.port = NWEndpoint.Port(rawValue: port)!
        self.handler = handler
    }

    /// Brings up both listeners; throws (and tears both down) if either cannot bind.
    func bind() async throws {
        for host in Self.loopbackHosts {
            let listener = try makeListener(host: host)
            queue.sync { listeners.append(listener) }
            try await waitUntilReady(listener)
        }
    }

    func stop() {
        queue.sync {
            listeners.forEach { $0.cancel() }
            listeners.removeAll()
        }
    }

    private func makeListener(host: NWEndpoint.Host) throws -> NWListener {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: host, port: port)
        // Why: this server closes the callback connection first, which parks the port in
        // TIME_WAIT for 2×MSL (30 s here); without reuse a retry inside that window would
        // burn the fallback port and a second retry would fail outright. Probed with BSD
        // sockets on macOS 27, 2026-09-16.
        parameters.allowLocalEndpointReuse = true
        let listener = try NWListener(using: parameters)
        listener.newConnectionHandler = { [weak self] connection in
            self?.serve(connection)
        }
        return listener
    }

    private func waitUntilReady(_ listener: NWListener) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            // Safe: every state update is delivered serially on `queue`.
            nonisolated(unsafe) var resumed = false
            listener.stateUpdateHandler = { state in
                guard !resumed else { return }
                switch state {
                case .ready:
                    resumed = true
                    continuation.resume()
                case .failed(let error):
                    resumed = true
                    continuation.resume(throwing: error)
                case .cancelled:
                    resumed = true
                    continuation.resume(throwing: CancellationError())
                default:
                    break
                }
            }
            listener.start(queue: queue)
        }
    }

    private func serve(_ connection: NWConnection) {
        connection.start(queue: queue)
        // One read is enough for a browser's GET: the request line is in the first segment.
        connection.receive(minimumIncompleteLength: 1, maximumLength: Self.maxRequestBytes) { [handler] data, _, _, _ in
            let target = data.flatMap(Self.requestTarget)
            Task {
                let reply = if let target { await handler(target) } else { Reply.badRequest }
                connection.send(content: reply.wire, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
        }
    }

    /// The request target from an HTTP/1.1 request line (`GET /callback?… HTTP/1.1`).
    private static func requestTarget(in data: Data) -> String? {
        guard let text = String(data: data, encoding: .utf8),
              let requestLine = text.split(separator: "\r\n", maxSplits: 1).first
        else { return nil }
        let parts = requestLine.split(separator: " ")
        guard parts.count == 3, parts[0] == "GET" else { return nil }
        return String(parts[1])
    }
}
