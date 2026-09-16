import Foundation
import TracklaudeCore

/// Replays a script of replies in order — one per request — and remembers what was sent.
/// A reply can be a thrown error, which is how "the network is down" is played.
actor ScriptedTransport: UsageTransport {
    private var replies: [Result<HTTPResponse, any Error>]
    private(set) var sent: [HTTPRequest] = []

    init(_ replies: [Result<HTTPResponse, any Error>]) {
        self.replies = replies
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        sent.append(request)
        precondition(!replies.isEmpty, "ScriptedTransport ran out of replies for \(request.method) \(request.url)")
        return try replies.removeFirst().get()
    }
}

/// Stands in for URLSession's network errors.
struct NetworkDown: Error {}
