import TracklaudeCore

/// Test adapter for the CredentialStore seam: holds at most one Credential in memory.
actor InMemoryCredentialStore: CredentialStore {
    private var credential: Credential?

    func load() async throws -> Credential? { credential }
    func save(_ credential: Credential) async throws { self.credential = credential }
    func delete() async throws { credential = nil }
}
