import Testing
import TracklaudeCore

private let expectedState = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8"

@Test("a /callback carrying the expected state yields its code")
func matchingStateIsAccepted() {
    let outcome = OAuthCallback.parse(
        requestTarget: "/callback?code=abc123&state=\(expectedState)",
        expectedState: expectedState
    )
    #expect(outcome == .accepted(code: "abc123"))
}

@Test("a callback whose state does not match is rejected even though it carries a code")
func mismatchedStateIsRejected() {
    let outcome = OAuthCallback.parse(
        requestTarget: "/callback?code=abc123&state=forged",
        expectedState: expectedState
    )
    #expect(outcome == .rejected(.stateMismatch))
}

@Test("a callback with no state at all is rejected")
func missingStateIsRejected() {
    let outcome = OAuthCallback.parse(requestTarget: "/callback?code=abc123", expectedState: expectedState)
    #expect(outcome == .rejected(.stateMismatch))
}

@Test("requests to any other path are rejected before state is even considered")
func otherPathsAreRejected() {
    let outcome = OAuthCallback.parse(requestTarget: "/favicon.ico", expectedState: expectedState)
    #expect(outcome == .rejected(.wrongPath))
}

@Test("a matching callback with no code is rejected")
func missingCodeIsRejected() {
    let outcome = OAuthCallback.parse(requestTarget: "/callback?state=\(expectedState)", expectedState: expectedState)
    #expect(outcome == .rejected(.missingCode))
}

@Test("a matching callback carrying error= reports the reason instead of a code")
func deniedCallbackReportsReason() {
    let outcome = OAuthCallback.parse(
        requestTarget: "/callback?error=access_denied&state=\(expectedState)",
        expectedState: expectedState
    )
    #expect(outcome == .rejected(.denied("access_denied")))
}
