import Foundation
import Testing
import TracklaudeCore

@Test("authorize URL targets claude.ai with PKCE S256, scope user:profile and Claude Code's public client id")
func authorizeURLCarriesEveryRequiredParameter() throws {
    let url = OAuthAuthorizeURL.build(
        state: "STATE",
        codeChallenge: "CHALLENGE",
        redirectURI: "http://localhost:1456/callback"
    )

    let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
    #expect(components.scheme == "https")
    #expect(components.host == "claude.ai")
    #expect(components.path == "/oauth/authorize")

    let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) })
    #expect(query == [
        "response_type": "code",
        "client_id": "9d1c250a-e61b-44d9-88ed-5944d1962f5e",
        "redirect_uri": "http://localhost:1456/callback",
        "scope": "user:profile",
        "code_challenge": "CHALLENGE",
        "code_challenge_method": "S256",
        "state": "STATE",
    ])
}
