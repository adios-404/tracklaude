import Foundation

/// Endpoints and identifiers for Anthropic's OAuth flow (ADR-0001).
/// Verified against Claude Code's own binary and a working third-party client, 2026-09-16.
public enum OAuthConfig {
    public static let authorizeURL = URL(string: "https://claude.ai/oauth/authorize")!
    public static let tokenURL = URL(string: "https://console.anthropic.com/v1/oauth/token")!

    /// The public client id Claude Code ships with. Public by design (PKCE, no secret).
    public static let clientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    public static let scope = "user:profile"

    /// Loopback callback ports: try the first, fall back to the second.
    public static let callbackPorts: [UInt16] = [1456, 1458]

    public static func redirectURI(port: UInt16) -> String {
        "http://localhost:\(port)\(OAuthCallback.path)"
    }
}
