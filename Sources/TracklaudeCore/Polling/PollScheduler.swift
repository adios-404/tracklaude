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
    case popoverOpened
    case manualRefresh
}

/// Decides when the next usage fetch happens. Pure: (state, now, last fetch, last manual
/// Refresh, trigger) in, a Date out — `nil` means "do not fetch". The executable owns the
/// actual timer.
public enum PollScheduler {
    /// 30 s flat (spec › Polling). Ticket 03 measured the endpoint reflecting new usage at
    /// ≤ 10 s, so the interval is not coarser than the data.
    public static let interval: TimeInterval = 30
    /// A double-click on Refresh must not double-fetch; the button is disabled this long
    /// after a manual Refresh. Why not after *any* fetch: opening the popover fetches too,
    /// and a Refresh button that is grey every time the popover appears reads as broken
    /// (observed 2026-09-16).
    public static let manualCooldown: TimeInterval = 5

    public static func nextFetch(
        state: PollState,
        now: Date,
        lastFetch: Date?,
        lastManualRefresh: Date?,
        trigger: PollTrigger
    ) -> Date? {
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
                return cadenceSlot(after: lastFetch, now: now)
            case .manualRefresh:
                return isManualRefreshAllowed(state: state, now: now, lastManualRefresh: lastManualRefresh)
                    ? now
                    : cadenceSlot(after: lastFetch, now: now)
            case .wake, .popoverOpened:
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

    /// The regular slot: 30 s after the last fetch, never in the past.
    private static func cadenceSlot(after lastFetch: Date?, now: Date) -> Date {
        guard let lastFetch else { return now }
        return max(lastFetch.addingTimeInterval(interval), now)
    }
}
