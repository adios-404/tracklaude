import Foundation

/// The signed-in session: holds the access token (memory only, ADR-0001), obtains one from
/// the Credential when there is none, and cures a 401 with one refresh and one retry
/// (spec › Sign-in). Every failure comes out as one `FetchFailure` the state machine can
/// apply; the HTTP details stay here.
public actor UsageSession {
    private var accessToken: String?
    private let store: any CredentialStore
    private let transport: any UsageTransport

    /// - Parameter accessToken: `nil` on a fresh launch, when only the Credential survived
    ///   and the first fetch has to start with a refresh.
    public init(store: any CredentialStore, transport: any UsageTransport, accessToken: String? = nil) {
        self.store = store
        self.transport = transport
        self.accessToken = accessToken
    }

    /// After a sign-in: the flow already stored the Credential; this keeps its access token.
    public func adopt(accessToken: String) {
        self.accessToken = accessToken
    }

    public func fetch(now: Date) async -> FetchResult {
        if accessToken == nil, let failure = await refreshAccessToken() {
            return .failed(failure)
        }
        do {
            return .snapshot(try await fetchOnce(now: now))
        } catch UsageFetchError.unauthorized {
            // Why: the token may simply have aged out (about an hour); the Credential can
            // still be good. One refresh, one retry, then the user has to sign in again.
            accessToken = nil
            if let failure = await refreshAccessToken() { return .failed(failure) }
            do {
                return .snapshot(try await fetchOnce(now: now))
            } catch {
                return .failed(Self.classify(error))
            }
        } catch {
            return .failed(Self.classify(error))
        }
    }

    private func fetchOnce(now: Date) async throws -> Snapshot {
        guard let accessToken else { throw UsageFetchError.unauthorized }
        return try await UsageFetch.perform(accessToken: accessToken, transport: transport, now: now)
    }

    /// Trades the stored Credential for an access token; `nil` on success. A rotated
    /// Credential is stored before anything else happens, because the old one is dead the
    /// moment the server rotates it.
    private func refreshAccessToken() async -> FetchFailure? {
        guard let credential = try? await store.load() else { return .sessionExpired }
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
