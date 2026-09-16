import Foundation

/// What the scheduler needs to know about the app right now. Ticket 05's state machine
/// maps onto these; the scheduler never sees a Snapshot.
public enum PollState: Equatable, Sendable {
    case signedOut
    /// Signed in, Mac awake.
    case active
    /// Signed in, Mac asleep: the timer is suspended.
    case asleep
}

/// Why the scheduler is being asked.
public enum PollTrigger: Equatable, Sendable, CaseIterable {
    /// The regular cadence: a fetch just finished, or polling is starting.
    case timer
    case wake
    case popoverOpened
    case manualRefresh
}

/// Decides when the next usage fetch happens. Pure: (state, now, last fetch, trigger) in,
/// a Date out — `nil` means "do not fetch". The executable owns the actual timer.
public enum PollScheduler {
    /// 30 s flat (spec › Polling). Ticket 03 measured the endpoint reflecting new usage at
    /// ≤ 10 s, so the interval is not coarser than the data.
    public static let interval: TimeInterval = 30
    /// A double-click on Refresh must not double-fetch; the button is disabled this long
    /// after any fetch. Measured from the last fetch, not the last click: a fetch that just
    /// landed on its own has nothing newer to show either.
    public static let manualCooldown: TimeInterval = 5

    public static func nextFetch(
        state: PollState,
        now: Date,
        lastFetch: Date?,
        trigger: PollTrigger
    ) -> Date? {
        switch state {
        case .signedOut, .asleep:
            return nil
        case .active:
            switch trigger {
            case .timer:
                return cadenceSlot(after: lastFetch, now: now)
            case .manualRefresh:
                return isManualRefreshAllowed(now: now, lastFetch: lastFetch)
                    ? now
                    : cadenceSlot(after: lastFetch, now: now)
            case .wake, .popoverOpened:
                return now
            }
        }
    }

    /// Drives the Refresh button's enabled state.
    public static func isManualRefreshAllowed(now: Date, lastFetch: Date?) -> Bool {
        guard let lastFetch else { return true }
        return now.timeIntervalSince(lastFetch) >= manualCooldown
    }

    /// The regular slot: 30 s after the last fetch, never in the past.
    private static func cadenceSlot(after lastFetch: Date?, now: Date) -> Date {
        guard let lastFetch else { return now }
        return max(lastFetch.addingTimeInterval(interval), now)
    }
}
