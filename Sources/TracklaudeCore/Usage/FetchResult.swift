import Foundation

/// Why a fetch produced no Snapshot, from the user's point of view. Each case is one Stale
/// reason (see CONTEXT.md); the HTTP details behind it stay in `UsageFetchError`.
public enum FetchFailure: Equatable, Sendable {
    /// The request never got an answer: no network, DNS, TLS, timeout.
    case offline
    /// 429; `retryAfter` is the server's `Retry-After` in seconds, when sent.
    case rateLimited(retryAfter: TimeInterval?)
    /// 5xx, an undecodable body, or a status the app has no rule for.
    case serverError
    /// The Credential no longer works: a 401 that a refresh could not cure.
    case sessionExpired
}

/// What one poll came back with.
public enum FetchResult: Equatable, Sendable {
    case snapshot(Snapshot)
    case failed(FetchFailure)
}
