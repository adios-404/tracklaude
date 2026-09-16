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
        guard !replies.isEmpty else { throw ScriptExhausted(request: request) }
        return try replies.removeFirst().get()
    }
}

/// More requests than the script had replies: the test's expectation was wrong, and the
/// session will report it as `offline`, which the assertion then catches.
struct ScriptExhausted: Error {
    let request: HTTPRequest
}

/// Stands in for URLSession's network errors.
struct NetworkDown: Error {}
