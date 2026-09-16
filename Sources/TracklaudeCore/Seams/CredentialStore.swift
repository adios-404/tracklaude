/// The OAuth refresh token the app holds (see CONTEXT.md). Never a session cookie.
public struct Credential: Equatable, Sendable {
    public var refreshToken: String

    public init(refreshToken: String) {
        self.refreshToken = refreshToken
    }
}

/// Where the Credential lives at rest. Production adapter is the Keychain (in the
/// executable); tests use an in-memory one. Holds at most one Credential.
public protocol CredentialStore: Sendable {
    func load() async throws -> Credential?
    func save(_ credential: Credential) async throws
    func delete() async throws
}
