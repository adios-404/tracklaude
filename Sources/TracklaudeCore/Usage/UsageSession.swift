import Foundation

/// The signed-in session: holds the Credential and the access token (memory only,
/// ADR-0001), obtains a token when there is none, and cures a 401 with one refresh and one
/// retry (spec › Sign-in). Every failure comes out as one `FetchFailure` the state machine
/// can apply; the HTTP details stay here.
///
/// Exists only while signed in: the executable creates one from the Credential it loaded
/// (a launch) or from the tokens a sign-in produced, so reading the store is never this
/// actor's problem and a Keychain read error is never mistaken for an expired session.
public actor UsageSession {
    private var credential: Credential
    private var accessToken: String?
    private let store: any CredentialStore
    private let transport: any UsageTransport

    /// - Parameter accessToken: `nil` on a fresh launch, when only the Credential survived
    ///   and the first fetch has to start with a refresh.
    public init(
        credential: Credential,
        accessToken: String? = nil,
        store: any CredentialStore,
        transport: any UsageTransport
    ) {
        self.credential = credential
        self.accessToken = accessToken
        self.store = store
        self.transport = transport
    }

    public func fetch(now: Date) async -> FetchResult {
        if accessToken == nil, let failure = await refreshAccessToken() {
            return .failed(failure)
        }
        let first = await attempt(now: now)
        guard first == .failed(.sessionExpired) else { return first }
        // Why: the token may simply have aged out (about an hour); the Credential can still
        // be good. One refresh, one retry, then the user has to sign in again.
        accessToken = nil
        if let failure = await refreshAccessToken() { return .failed(failure) }
        return await attempt(now: now)
    }

    /// One usage request with the token in hand; a 401 reads as `sessionExpired` here and the
    /// caller decides whether a refresh is still owed.
    private func attempt(now: Date) async -> FetchResult {
        guard let accessToken else { return .failed(.sessionExpired) }
        do {
            return .snapshot(try await UsageFetch.perform(accessToken: accessToken, transport: transport, now: now))
        } catch {
            return .failed(Self.classify(error))
        }
    }

    /// Trades the Credential for an access token; `nil` on success. A rotated Credential is
    /// stored before anything else happens, because the old one is dead the moment the
    /// server rotates it.
    private func refreshAccessToken() async -> FetchFailure? {
        let tokens: OAuthTokens
        do {
            tokens = try await OAuthRefresh.refresh(credential, transport: transport)
        } catch {
            return Self.classifyRefresh(error)
        }
        if tokens.refreshToken != credential.refreshToken {
            do {
                try await store.save(Credential(refreshToken: tokens.refreshToken))
            } catch {
                // Why: the server has already retired the old Credential; a rotated one
                // that cannot be kept means the next launch cannot sign in silently. Say so
                // now, while the user can act, rather than an hour from now.
                return .sessionExpired
            }
            credential = Credential(refreshToken: tokens.refreshToken)
        }
        accessToken = tokens.accessToken
        return nil
    }

    private static func classify(_ error: any Error) -> FetchFailure {
        switch error {
        case UsageFetchError.unauthorized: return .sessionExpired
        case UsageFetchError.rateLimited(let retryAfter): return .rateLimited(retryAfter: retryAfter)
        case UsageFetchError.serverError, UsageFetchError.undecodable, UsageFetchError.unexpectedStatus: return .serverError
        // Anything the transport threw: the request never got an answer.
        default: return .offline
        }
    }

    private static func classifyRefresh(_ error: any Error) -> FetchFailure {
        switch error {
        // 400 is what `invalid_grant` arrives as; 401/403 are the same story.
        case OAuthTokenError.httpStatus(400), OAuthTokenError.httpStatus(401), OAuthTokenError.httpStatus(403):
            return .sessionExpired
        case OAuthTokenError.httpStatus(429):
            return .rateLimited(retryAfter: nil)
        case OAuthTokenError.httpStatus, OAuthTokenError.undecodableResponse:
            return .serverError
        default:
            return .offline
        }
    }
}
