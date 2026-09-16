import Foundation
import Testing
import TracklaudeCore

private let credential = Credential(refreshToken: "sk-ant-ort01-OLD")

@Test("refresh POSTs the refresh_token grant as JSON to the token endpoint")
func refreshSendsRefreshTokenGrant() async throws {
    let transport = FakeTransport(replying: try Fixture.jsonResponse("oauth-token-response.json"))

    _ = try await OAuthRefresh.refresh(credential, transport: transport)

    let request = try #require(await transport.sent.first)
    #expect(request.method == "POST")
    #expect(request.url.absoluteString == "https://console.anthropic.com/v1/oauth/token")
    #expect(request.headers["Content-Type"] == "application/json")
    let body = try JSONDecoder().decode([String: String].self, from: try #require(request.body))
    #expect(body == [
        "grant_type": "refresh_token",
        "refresh_token": "sk-ant-ort01-OLD",
        "client_id": "9d1c250a-e61b-44d9-88ed-5944d1962f5e",
    ])
}

@Test("a successful refresh yields the new access token and the rotated refresh token")
func refreshReturnsRotatedTokens() async throws {
    let transport = FakeTransport(replying: try Fixture.jsonResponse("oauth-token-response.json"))

    let tokens = try await OAuthRefresh.refresh(credential, transport: transport)

    #expect(tokens == OAuthTokens(
        accessToken: "sk-ant-oat01-ACCESS", refreshToken: "sk-ant-ort01-REFRESH", expiresIn: 3600
    ))
}

@Test("when the server omits refresh_token the existing Credential stays valid")
func refreshKeepsOldRefreshTokenWhenNotRotated() async throws {
    let transport = FakeTransport(replying: .json(
        status: 200, #"{"token_type":"Bearer","access_token":"sk-ant-oat01-NEW","expires_in":3600}"#
    ))

    let tokens = try await OAuthRefresh.refresh(credential, transport: transport)

    #expect(tokens.accessToken == "sk-ant-oat01-NEW")
    #expect(tokens.refreshToken == "sk-ant-ort01-OLD")
}

@Test("a non-2xx refresh response is reported with its status")
func refreshSurfacesHTTPFailure() async {
    let transport = FakeTransport(replying: .json(status: 400, #"{"error":"invalid_grant"}"#))

    await #expect(throws: OAuthTokenError.httpStatus(400)) {
        try await OAuthRefresh.refresh(credential, transport: transport)
    }
}
