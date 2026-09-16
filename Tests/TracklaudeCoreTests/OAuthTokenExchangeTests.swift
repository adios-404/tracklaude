import Foundation
import Testing
import TracklaudeCore

// Body shape as documented in research/usage4claude-study.md §5 (verified 2026-09-16).
private let tokenResponse = "oauth-token-response.json"

@Test("code exchange POSTs the authorization_code grant as JSON to the token endpoint")
func exchangeSendsAuthorizationCodeGrant() async throws {
    let transport = FakeTransport(replying: try Fixture.jsonResponse(tokenResponse))

    _ = try await OAuthTokenExchange.exchange(
        code: "CODE", state: "STATE", codeVerifier: "VERIFIER",
        redirectURI: "http://localhost:1456/callback", transport: transport
    )

    let request = try #require(await transport.sent.first)
    #expect(request.method == "POST")
    #expect(request.url.absoluteString == "https://console.anthropic.com/v1/oauth/token")
    #expect(request.headers["Content-Type"] == "application/json")
    let body = try JSONDecoder().decode([String: String].self, from: try #require(request.body))
    #expect(body == [
        "grant_type": "authorization_code",
        "code": "CODE",
        "state": "STATE",
        "redirect_uri": "http://localhost:1456/callback",
        "client_id": "9d1c250a-e61b-44d9-88ed-5944d1962f5e",
        "code_verifier": "VERIFIER",
    ])
}

@Test("a successful exchange yields the access and refresh tokens")
func exchangeReturnsBothTokens() async throws {
    let transport = FakeTransport(replying: try Fixture.jsonResponse(tokenResponse))

    let tokens = try await OAuthTokenExchange.exchange(
        code: "CODE", state: "STATE", codeVerifier: "VERIFIER",
        redirectURI: "http://localhost:1456/callback", transport: transport
    )

    #expect(tokens == OAuthTokens(
        accessToken: "sk-ant-oat01-ACCESS",
        refreshToken: "sk-ant-ort01-REFRESH",
        expiresIn: 3600
    ))
}

@Test("a non-2xx token response is reported with its status, never decoded as tokens")
func exchangeSurfacesHTTPFailure() async {
    let transport = FakeTransport(replying: .json(status: 400, #"{"error":"invalid_grant"}"#))

    await #expect(throws: OAuthTokenError.httpStatus(400)) {
        try await OAuthTokenExchange.exchange(
            code: "CODE", state: "STATE", codeVerifier: "VERIFIER",
            redirectURI: "http://localhost:1456/callback", transport: transport
        )
    }
}

@Test("a 200 whose body is not the token shape is reported as undecodable")
func exchangeSurfacesUndecodableBody() async {
    let transport = FakeTransport(replying: HTTPResponse(status: 200, body: Data("<html>".utf8)))

    await #expect(throws: OAuthTokenError.undecodableResponse) {
        try await OAuthTokenExchange.exchange(
            code: "CODE", state: "STATE", codeVerifier: "VERIFIER",
            redirectURI: "http://localhost:1456/callback", transport: transport
        )
    }
}
