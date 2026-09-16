import Testing
import TracklaudeCore

// Expected values are the worked example in RFC 7636 Appendix B, not recomputed here.
private let rfc7636Octets: [UInt8] = [
    116, 24, 223, 180, 151, 153, 224, 37, 79, 250, 96, 125, 216, 173, 187, 186,
    22, 212, 37, 77, 105, 214, 191, 240, 91, 88, 5, 88, 83, 132, 141, 121,
]

@Test("PKCE verifier is the base64url encoding of the random octets, without padding")
func verifierMatchesRFC7636Example() {
    #expect(PKCE.verifier(from: rfc7636Octets) == "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
}

@Test("PKCE S256 challenge matches the RFC 7636 example")
func challengeMatchesRFC7636Example() {
    #expect(PKCE.challenge(for: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk") == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
}

@Test("OAuth state is the base64url encoding of its random octets, so it is URL-safe as-is")
func stateIsBase64URLOfOctets() {
    // Expected string computed independently with Python's base64.urlsafe_b64encode.
    #expect(PKCE.state(from: Array(0..<32)) == "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8")
}
