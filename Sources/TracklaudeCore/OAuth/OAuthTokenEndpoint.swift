import Foundation

/// The one POST both grants share: JSON body to the token endpoint, tokens back.
enum OAuthTokenEndpoint {
    /// - Parameter currentRefreshToken: kept when the reply carries no `refresh_token`
    ///   (the refresh grant may not rotate it); `nil` means the reply must include one.
    static func post(
        grant: [String: String],
        currentRefreshToken: String?,
        transport: any UsageTransport
    ) async throws -> OAuthTokens {
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
        return try decode(response.body, currentRefreshToken: currentRefreshToken)
    }

    private struct Wire: Decodable {
        let accessToken: String
        let refreshToken: String?
        let expiresIn: TimeInterval?
    }

    private static func decode(_ body: Data, currentRefreshToken: String?) throws -> OAuthTokens {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let wire = try? decoder.decode(Wire.self, from: body),
              let refreshToken = wire.refreshToken ?? currentRefreshToken
        else {
            throw OAuthTokenError.undecodableResponse
        }
        return OAuthTokens(
            accessToken: wire.accessToken,
            refreshToken: refreshToken,
            expiresIn: wire.expiresIn
        )
    }
}
