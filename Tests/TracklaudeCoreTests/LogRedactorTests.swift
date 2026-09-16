import Testing
import TracklaudeCore

// Fake Credentials in the shape Anthropic issues: `sk-ant-<kind>-<base64url body>`.
private let accessToken = "sk-ant-oat01-Ab3dEf7GhIjKlMnOpQrStUvWxYz0123456789_-AbCdEfGh"
private let refreshToken = "sk-ant-ort01-Zy9xWv8UtSrQpOnMlKjIhGfEdCbA9876543210-_ZyXwVuTs"

@Test("an access token anywhere in a message is replaced, the rest of the message survives")
func accessTokenIsRedacted() {
    let redacted = LogRedactor.redact("token refresh returned \(accessToken) for the session")

    #expect(redacted == "token refresh returned [redacted] for the session")
}

@Test("a refresh token is redacted the same way as an access token")
func refreshTokenIsRedacted() {
    #expect(LogRedactor.redact("saved \(refreshToken)") == "saved [redacted]")
}

@Test("a Bearer header value is redacted whatever shape the value has")
func bearerValueIsRedacted() {
    let redacted = LogRedactor.redact("Authorization: Bearer abc.DEF-123_456=/+ done")

    #expect(redacted == "Authorization: Bearer [redacted] done")
}

@Test("a JSON refresh_token field is redacted even when its value is not token-shaped")
func jsonRefreshTokenIsRedacted() {
    let body = #"{"access_token":"short","refresh_token": "also-short","expires_in":3600}"#

    let redacted = LogRedactor.redact(body)

    #expect(redacted == #"{"access_token":"[redacted]","refresh_token":"[redacted]","expires_in":3600}"#)
}

@Test("a message with no secret passes through unchanged")
func plainMessageIsUnchanged() {
    let message = "State: polling → backingOff(429 #5); sk-ant is not a token, nor is Bearerless"

    #expect(LogRedactor.redact(message) == message)
}

@Test("every secret in a message is redacted, not just the first")
func everySecretIsRedacted() {
    let redacted = LogRedactor.redact("\(accessToken) then \(refreshToken) then Bearer xyz")

    #expect(redacted == "[redacted] then [redacted] then Bearer [redacted]")
}
