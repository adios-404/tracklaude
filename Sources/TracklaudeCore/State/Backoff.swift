import Foundation

/// How long to wait after a 429 before asking again (spec › Polling).
///
/// Pure. The schedule is ours; a `Retry-After` header is the server's and wins outright —
/// observed 2026-09-16: the lockout ends at exactly `Retry-After` seconds, and requests
/// made inside it are refused but do not extend it, so there is nothing to gain by
/// second-guessing the header in either direction.
public enum Backoff {
    public static let firstDelay: TimeInterval = 60
    /// Ticket 13 cut it from 600 to 300; ticket 16 to 120. Refusals without a Retry-After
    /// lasted 1–17 min whatever this app's rate (observed 2026-10-03), so a longer wait only
    /// delays the first good reading after they stop. A positive Retry-After still wins.
    public static let cap: TimeInterval = 120

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
