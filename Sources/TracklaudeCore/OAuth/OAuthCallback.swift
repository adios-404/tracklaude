import Foundation

/// Decides whether one HTTP request to the loopback server is the sign-in callback we are
/// waiting for. Pure: the socket layer hands in the request target, this hands back a verdict.
public enum OAuthCallback {
    public static let path = "/callback"

    public enum Outcome: Equatable, Sendable {
        case accepted(code: String)
        case rejected(Rejection)
    }

    public enum Rejection: Equatable, Sendable {
        case wrongPath
        case stateMismatch
        case missingCode
        /// Anthropic redirected back with `error=<reason>` instead of a code (e.g. the user declined).
        case denied(String)
    }

    /// - Parameter requestTarget: the path-and-query from the HTTP request line, e.g. `/callback?code=…&state=…`.
    public static func parse(requestTarget: String, expectedState: String) -> Outcome {
        guard let components = URLComponents(string: requestTarget), components.path == path else {
            return .rejected(.wrongPath)
        }
        let query = Dictionary(
            (components.queryItems ?? []).map { ($0.name, $0.value ?? "") },
            uniquingKeysWith: { first, _ in first }
        )
        guard query["state"] == expectedState else { return .rejected(.stateMismatch) }
        if let error = query["error"] { return .rejected(.denied(error)) }
        guard let code = query["code"], !code.isEmpty else { return .rejected(.missingCode) }
        return .accepted(code: code)
    }
}
