import Foundation
import TracklaudeCore

/// Production UsageTransport: URLSession with a 30 s request timeout and HTTP/3 off.
struct URLSessionTransport: UsageTransport {
    static let requestTimeout: TimeInterval = 30

    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = Self.requestTimeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration)
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        urlRequest.assumesHTTP3Capable = false
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }

        let (body, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else { throw TransportError.notHTTP }
        let headers = Dictionary(
            http.allHeaderFields.compactMap { key, value -> (String, String)? in
                guard let name = key as? String, let text = value as? String else { return nil }
                return (name, text)
            },
            uniquingKeysWith: { first, _ in first }
        )
        return HTTPResponse(status: http.statusCode, headers: headers, body: body)
    }
}

enum TransportError: Error {
    case notHTTP
}
