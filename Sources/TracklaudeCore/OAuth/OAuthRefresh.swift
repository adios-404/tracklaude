/// Trades the stored Credential for a fresh access token (RFC 6749 §6).
///
/// The reply's refresh token, when present, is the rotated Credential: the caller must save
/// it to the CredentialStore at once, or the next refresh fails with `invalid_grant`.
public enum OAuthRefresh {
    public static func refresh(
        _ credential: Credential,
        transport: any UsageTransport
    ) async throws -> OAuthTokens {
        try await OAuthTokenEndpoint.post(
            grant: [
                "grant_type": "refresh_token",
                "refresh_token": credential.refreshToken,
                "client_id": OAuthConfig.clientID,
            ],
            currentRefreshToken: credential.refreshToken,
            transport: transport
        )
    }
}
