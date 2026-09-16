import Foundation

/// Why the displayed Snapshot is Stale (see CONTEXT.md). One word each in the menu bar.
public enum StaleReason: Equatable, Sendable, CaseIterable {
    case offline
    case rateLimited
    case sessionExpired
    case serverError
}

/// Where the app stands (spec › Architecture). The UI renders the state; `applying`
/// decides the transitions. Every signed-in case carries the last Snapshot so a failure
/// never blanks the readout.
public enum AppState: Equatable, Sendable {
    case signedOut
    case signingIn
    /// Signed in, fetching every 30 s. `nil` until the first Snapshot lands.
    case polling(Snapshot?)
    /// The last fetch failed; the Snapshot shown is the last good one.
    case stale(Snapshot?, StaleReason)
    /// A 429: no fetch until `until`. `consecutiveRateLimits` is how many 429s in a row this
    /// makes, which sets the next delay if the one after `until` is refused too.
    case backingOff(Snapshot?, until: Date, consecutiveRateLimits: Int)

    /// The Snapshot on screen, if any.
    public var lastSnapshot: Snapshot? {
        switch self {
        case .signedOut, .signingIn: return nil
        case .polling(let snapshot), .stale(let snapshot, _), .backingOff(let snapshot, _, _): return snapshot
        }
    }

    /// Whether a fetch result may be applied: the three states that came from a sign-in.
    public var isSignedIn: Bool {
        switch self {
        case .signedOut, .signingIn: return false
        case .polling, .stale, .backingOff: return true
        }
    }

    /// Backing off is rate limiting from the user's point of view.
    public var staleReason: StaleReason? {
        switch self {
        case .stale(_, let reason): return reason
        case .backingOff: return .rateLimited
        case .signedOut, .signingIn, .polling: return nil
        }
    }

    /// The next state after a fetch lands. `now` is when it landed; backoff counts from there.
    public func applying(_ result: FetchResult, now: Date) -> AppState {
        let snapshot = lastSnapshot
        switch result {
        case .snapshot(let fresh):
            return .polling(fresh)
        case .failed(.offline):
            return .stale(snapshot, .offline)
        case .failed(.serverError):
            return .stale(snapshot, .serverError)
        case .failed(.sessionExpired):
            return .stale(snapshot, .sessionExpired)
        case .failed(.rateLimited(let retryAfter)):
            let count = consecutiveRateLimits + 1
            let delay = Backoff.delay(consecutiveRateLimits: count, retryAfter: retryAfter)
            return .backingOff(snapshot, until: now.addingTimeInterval(delay), consecutiveRateLimits: count)
        }
    }

    private var consecutiveRateLimits: Int {
        if case .backingOff(_, _, let count) = self { return count }
        return 0
    }
}
