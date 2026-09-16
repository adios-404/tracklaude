import Foundation

/// What the token endpoint hands back. The refresh token becomes the Credential; the access
/// token lives in memory only.
public struct OAuthTokens: Equatable, Sendable {
    public var accessToken: String
    public var refreshToken: String
    /// Seconds until the access token expires, when the server says.
    public var expiresIn: TimeInterval?

    public init(accessToken: String, refreshToken: String, expiresIn: TimeInterval?) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresIn = expiresIn
    }
}

public enum OAuthTokenError: Error, Equatable, Sendable {
    case httpStatus(Int)
    case undecodableResponse
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
        let grant: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "state": state,
            "redirect_uri": redirectURI,
            "client_id": OAuthConfig.clientID,
            "code_verifier": codeVerifier,
        ]
        let request = HTTPRequest(
            method: "POST",
            url: OAuthConfig.tokenURL,
            headers: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(grant)
        )
        let response = try await transport.send(request)
        guard (200..<300).contains(response.status) else {
            throw OAuthTokenError.httpStatus(response.status)
        }
        return try decode(response.body)
    }

    private struct Wire: Decodable {
        let access_token: String
        let refresh_token: String
        let expires_in: TimeInterval?
    }

    private static func decode(_ body: Data) throws -> OAuthTokens {
        guard let wire = try? JSONDecoder().decode(Wire.self, from: body) else {
            throw OAuthTokenError.undecodableResponse
        }
        return OAuthTokens(
            accessToken: wire.access_token,
            refreshToken: wire.refresh_token,
            expiresIn: wire.expires_in
        )
    }
}
