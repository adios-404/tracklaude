import Foundation

/// How long to wait after a 429 before asking again (spec › Polling).
///
/// Pure. The schedule is ours; a `Retry-After` header is the server's and wins outright —
/// observed 2026-09-16: the lockout ends at exactly `Retry-After` seconds, and requests
/// made inside it are refused but do not extend it, so there is nothing to gain by
/// second-guessing the header in either direction.
public enum Backoff {
    public static let firstDelay: TimeInterval = 60
    /// Ticket 13: was 600. A lockout of 8–10 min, with Refresh greyed out throughout,
    /// read as a hung app; the slowed cadence after a 429 now does the budget-saving.
    public static let cap: TimeInterval = 300

    /// - Parameter consecutiveRateLimits: how many 429s in a row this one makes (1-based).
    public static func delay(consecutiveRateLimits: Int, retryAfter: TimeInterval?) -> TimeInterval {
        // Why: `Retry-After: 0` was observed 2026-09-17 on an ordinary 30 s poll. Honoured
        // literally it means "retry now", which re-fetches instantly, gets another `0`, and
        // floods the endpoint (22,000 requests in eight minutes). A non-positive header says
        // nothing about when to come back, so the schedule applies as if it were absent.
        if let retryAfter, retryAfter > 0 { return retryAfter }
        let doublings = max(0, consecutiveRateLimits - 1)
        return min(firstDelay * pow(2, Double(doublings)), cap)
    }
}
