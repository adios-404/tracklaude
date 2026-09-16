import Foundation

/// What the token endpoint hands back. The refresh token becomes the Credential; the access
/// token lives in memory only.
public struct OAuthTokens: Equatable, Sendable {
    public let accessToken: String
    public let refreshToken: String
    /// Seconds until the access token expires, when the server says.
    public let expiresIn: TimeInterval?

    public init(accessToken: String, refreshToken: String, expiresIn: TimeInterval?) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresIn = expiresIn
    }
}

public enum OAuthTokenError: Error, Equatable, Sendable, LocalizedError {
    case httpStatus(Int)
    case undecodableResponse

    public var errorDescription: String? {
        switch self {
        case .httpStatus(let status):
            return "Anthropic refused the sign-in code (HTTP \(status))."
        case .undecodableResponse:
            return "Anthropic's reply to the sign-in code was not in the expected format."
        }
    }
}

/// Trades the authorization code from the callback for tokens (RFC 6749 §4.1.3 + PKCE).
public enum OAuthTokenExchange {
    public static func exchange(
        code: String,
        state: String,
        codeVerifier: String,
        redirectURI: String,
        transport: any UsageTransport
    ) async throws -> OAuthTokens {
        try await OAuthTokenEndpoint.post(
            grant: [
                "grant_type": "authorization_code",
                "code": code,
                "state": state,
                "redirect_uri": redirectURI,
                "client_id": OAuthConfig.clientID,
                "code_verifier": codeVerifier,
            ],
            currentRefreshToken: nil,
            transport: transport
        )
    }
}
