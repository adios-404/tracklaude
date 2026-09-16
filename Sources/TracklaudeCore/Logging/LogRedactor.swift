import Foundation

/// Strips Credentials from a message before it reaches the unified log, so "help me
/// debug" (`log show`) can never hand over a token. Pure: same input, same output.
public enum LogRedactor {
    public static let placeholder = "[redacted]"

    // Why computed: `Regex` is not `Sendable`, so a stored static would be a global-state
    // error under strict concurrency. Rebuilding a literal per call is cheap on a log path.

    /// Anthropic-issued tokens: `sk-ant-<kind>-<body>`, e.g. `sk-ant-oat01-…` (access) and
    /// `sk-ant-ort01-…` (refresh). The body is base64url, well over 20 characters.
    private static var anthropicToken: Regex<Substring> { /sk-ant-[a-z0-9]{2,5}-[A-Za-z0-9_-]{20,}/ }

    /// A `Bearer` header value, whatever its shape: the scheme word, whitespace, one token.
    private static var bearerValue: Regex<Substring> { /Bearer\s+\S+/ }

    /// The token fields of an OAuth token-endpoint body, even when the value is not
    /// token-shaped (a truncated or malformed reply is still not for the log).
    private static var jsonTokenField: Regex<(Substring, Substring)> {
        /"(access_token|refresh_token)"\s*:\s*"[^"]*"/
    }

    public static func redact(_ message: String) -> String {
        message
            .replacing(jsonTokenField) { match in #""\#(match.1)":"\#(placeholder)""# }
            .replacing(anthropicToken, with: placeholder)
            .replacing(bearerValue, with: "Bearer \(placeholder)")
    }
}
