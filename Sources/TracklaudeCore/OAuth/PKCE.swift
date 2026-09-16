import CryptoKit
import Foundation

/// RFC 7636 Proof Key for Code Exchange, S256 method.
///
/// Pure: randomness is injected as octets so callers (and tests) control it.
public enum PKCE {
    /// Number of random octets behind a verifier; 32 gives the 43-character verifier RFC 7636 recommends.
    public static let verifierOctetCount = 32

    /// `code_verifier`: the octets, base64url-encoded without padding.
    public static func verifier(from octets: [UInt8]) -> String {
        Base64URL.encode(Data(octets))
    }

    /// `code_challenge` for the S256 method: base64url(SHA-256(ascii(verifier))).
    public static func challenge(for verifier: String) -> String {
        Base64URL.encode(Data(SHA256.hash(data: Data(verifier.utf8))))
    }
}

enum Base64URL {
    static func encode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

extension PKCE {
    /// Number of random octets behind a `state` value.
    public static let stateOctetCount = 32

    /// OAuth `state`: an unguessable value the callback must echo back. Same encoding as the
    /// verifier so it needs no further escaping in a URL.
    public static func state(from octets: [UInt8]) -> String {
        Base64URL.encode(Data(octets))
    }
}
