import Foundation

/// What the scheduler needs to know about the app right now. Ticket 05's state machine
/// maps onto these; the scheduler never sees a Snapshot.
public enum PollState: Equatable, Sendable {
    case signedOut
    /// Signed in, Mac awake.
    case active
    /// Signed in, Mac asleep: the timer is suspended.
    case asleep
    /// A 429 said not before `until`. Nothing — not even Refresh — fetches earlier.
    case backingOff(until: Date)
}

/// Why the scheduler is being asked.
public enum PollTrigger: Equatable, Sendable, CaseIterable {
    /// The regular cadence: a fetch just finished, or polling is starting.
    case timer
    case wake
    case manualRefresh
}

/// Decides when the next usage fetch happens. Pure: (state, now, last fetch, last manual
/// Refresh, last 429, trigger) in, a Date out — `nil` means "do not fetch". The executable
/// owns the actual timer.
public enum PollScheduler {
    /// While no 429 is recent (spec › Polling). Ticket 03 measured the endpoint reflecting
    /// new usage at ≤ 10 s, so the interval is not coarser than the data.
    public static let interval: TimeInterval = 30
    /// The cadence for `slowdownPeriod` after any 429 (ticket 13). The usage endpoint's
    /// budget — about 20–25 requests per 10 min — is per account and shared with whatever
    /// else asks; at 30 s this app alone spends 20. Snapping back to 30 s after one success
    /// drew the next 429 within a minute, for hours (observed 2026-10-02). 120 s spends 5.
    public static let rateLimitedInterval: TimeInterval = 120
    public static let slowdownPeriod: TimeInterval = 30 * 60
    /// A double-click on Refresh must not double-fetch; the button is disabled this long
    /// after a manual Refresh. Why not after *any* fetch: the timer fetches every 30 s,
    /// and a Refresh button that is grey every time the popover appears reads as broken
    /// (observed 2026-09-16).
    public static let manualCooldown: TimeInterval = 5

    public static func nextFetch(
        state: PollState,
        now: Date,
        lastFetch: Date?,
        lastManualRefresh: Date?,
        lastRateLimit: Date?,
        trigger: PollTrigger
    ) -> Date? {
        let cadence = cadence(now: now, lastRateLimit: lastRateLimit)
        switch state {
        case .signedOut, .asleep:
            return nil
        case .backingOff(let until):
            // Why: requests inside a lockout are refused, not punished (observed 2026-09-16),
            // so an early Refresh only wastes budget. Never in the past: the Mac may have
            // slept through `until`.
            return max(until, now)
        case .active:
            switch trigger {
            case .timer:
                return cadenceSlot(after: lastFetch, now: now, cadence: cadence)
            case .manualRefresh:
                return isManualRefreshAllowed(state: state, now: now, lastManualRefresh: lastManualRefresh)
                    ? now
                    : cadenceSlot(after: lastFetch, now: now, cadence: cadence)
            case .wake:
                return now
            }
        }
    }

    /// Drives the Refresh button's enabled state.
    public static func isManualRefreshAllowed(state: PollState, now: Date, lastManualRefresh: Date?) -> Bool {
        if case .backingOff(let until) = state, until > now { return false }
        guard let lastManualRefresh else { return true }
        return now.timeIntervalSince(lastManualRefresh) >= manualCooldown
    }

    /// The regular interval: slowed while a 429 is recent, 30 s otherwise. Only the timer
    /// slows; wake and Refresh still fetch at once.
    private static func cadence(now: Date, lastRateLimit: Date?) -> TimeInterval {
        guard let lastRateLimit, now.timeIntervalSince(lastRateLimit) < slowdownPeriod else { return interval }
        return rateLimitedInterval
    }

    /// The regular slot: one cadence after the last fetch, never in the past.
    private static func cadenceSlot(after lastFetch: Date?, now: Date, cadence: TimeInterval) -> Date {
        guard let lastFetch else { return now }
        return max(lastFetch.addingTimeInterval(cadence), now)
    }
}
