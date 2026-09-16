import Foundation
import TracklaudeCore

/// Replays one canned response and remembers what was sent.
actor FakeTransport: UsageTransport {
    private let response: HTTPResponse
    private(set) var sent: [HTTPRequest] = []

    init(replying response: HTTPResponse) {
        self.response = response
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        sent.append(request)
        return response
    }
}

extension HTTPResponse {
    static func json(status: Int, _ body: String) -> HTTPResponse {
        HTTPResponse(status: status, headers: ["Content-Type": "application/json"], body: Data(body.utf8))
    }
}
