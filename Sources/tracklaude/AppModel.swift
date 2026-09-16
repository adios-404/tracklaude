import AppKit
import Observation
import os
import TracklaudeCore

/// Where the app stands with Anthropic. Grows into the spec's full state machine in later tickets.
enum AuthState: Equatable {
    case signedOut
    case signingIn
    case signedIn
    case failed(String)
}

@Observable
@MainActor
final class AppModel {
    private(set) var auth: AuthState = .signedOut
    /// The latest successful fetch; the menu bar renders its 5-hour Window.
    private(set) var snapshot: Snapshot?
    /// Plain-English reason the last fetch produced no Snapshot. Ticket 05 turns this into Stale.
    private(set) var fetchFailure: String?

    /// Memory only — never persisted (ADR-0001).
    private var accessToken: String?
    private var signInTask: Task<Void, Never>?

    private let store: any CredentialStore
    private let transport: any UsageTransport

    init(
        store: any CredentialStore = KeychainCredentialStore(),
        transport: any UsageTransport = URLSessionTransport()
    ) {
        self.store = store
        self.transport = transport
        Task { await restoreCredential() }
    }

    /// On launch: a stored Credential means the user is signed in without asking again.
    /// Only the Credential survives a relaunch, so the first fetch starts with a refresh.
    private func restoreCredential() async {
        do {
            guard let credential = try await store.load() else { return }
            auth = .signedIn
            try await refreshAccessToken(with: credential)
            await fetchUsage()
        } catch {
            // Status text only — never the Credential.
            Self.log.error("Could not restore the session: \(error.localizedDescription, privacy: .public)")
            auth = .failed(error.localizedDescription)
        }
    }

    /// Trades the Credential for an access token; a rotated Credential is stored at once,
    /// because the old one is dead the moment the server rotates it.
    private func refreshAccessToken(with credential: Credential) async throws {
        let tokens = try await OAuthRefresh.refresh(credential, transport: transport)
        accessToken = tokens.accessToken
        if tokens.refreshToken != credential.refreshToken {
            try await store.save(Credential(refreshToken: tokens.refreshToken))
        }
    }

    private func fetchUsage() async {
        guard let accessToken else { return }
        do {
            snapshot = try await UsageFetch.perform(accessToken: accessToken, transport: transport, now: Date())
            fetchFailure = nil
        } catch {
            Self.log.error("Usage fetch failed: \(error.localizedDescription, privacy: .public)")
            fetchFailure = error.localizedDescription
        }
    }

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "tracklaude", category: "auth")

    func signIn() {
        guard signInTask == nil else { return }
        auth = .signingIn
        let flow = SignIn(
            listener: LoopbackCallbackServer(),
            openURL: { url in
                await MainActor.run { _ = NSWorkspace.shared.open(url) }
            },
            transport: transport,
            store: store
        )
        signInTask = Task {
            defer { signInTask = nil }
            do {
                let tokens = try await flow.run()
                accessToken = tokens.accessToken
                auth = .signedIn
                await fetchUsage()
            } catch {
                // Why: a cancelled URLSession request surfaces as URLError.cancelled, not
                // CancellationError, so the task flag is the reliable signal for "user cancelled".
                auth = Task.isCancelled || error is CancellationError
                    ? .signedOut
                    : .failed(error.localizedDescription)
            }
        }
    }

    func cancelSignIn() {
        signInTask?.cancel()
    }
}
