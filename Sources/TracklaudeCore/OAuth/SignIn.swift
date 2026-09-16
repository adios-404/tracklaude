import Foundation

/// One sign-in, end to end: PKCE → loopback listener → browser → code → tokens → Credential.
///
/// Every side effect is injected, so the whole flow runs under test with fakes.
public struct SignIn: Sendable {
    public var randomOctets: @Sendable (Int) -> [UInt8]
    public var listener: any CallbackListener
    public var openURL: @Sendable (URL) async throws -> Void
    public var transport: any UsageTransport
    public var store: any CredentialStore

    public init(
        randomOctets: @escaping @Sendable (Int) -> [UInt8] = SecureRandom.octets,
        listener: any CallbackListener,
        openURL: @escaping @Sendable (URL) async throws -> Void,
        transport: any UsageTransport,
        store: any CredentialStore
    ) {
        self.randomOctets = randomOctets
        self.listener = listener
        self.openURL = openURL
        self.transport = transport
        self.store = store
    }

    /// Runs the flow. On success the refresh token is already in `store`; the returned tokens
    /// carry the access token, which the caller keeps in memory only.
    public func run() async throws -> OAuthTokens {
        let verifier = PKCE.verifier(from: randomOctets(PKCE.verifierOctetCount))
        let state = PKCE.state(from: randomOctets(PKCE.stateOctetCount))

        let port = try await listener.start(expectedState: state)
        let redirectURI = OAuthConfig.redirectURI(port: port)
        do {
            try await openURL(OAuthAuthorizeURL.build(
                state: state, codeChallenge: PKCE.challenge(for: verifier), redirectURI: redirectURI
            ))
            let code = try await listener.awaitCode()
            let tokens = try await OAuthTokenExchange.exchange(
                code: code, state: state, codeVerifier: verifier,
                redirectURI: redirectURI, transport: transport
            )
            try await store.save(Credential(refreshToken: tokens.refreshToken))
            return tokens
        } catch {
            await listener.cancel()
            throw error
        }
    }
}

public enum SecureRandom {
    /// Cryptographically secure octets (SystemRandomNumberGenerator is backed by the OS CSPRNG).
    public static func octets(count: Int) -> [UInt8] {
        var generator = SystemRandomNumberGenerator()
        return (0..<count).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
    }
}
