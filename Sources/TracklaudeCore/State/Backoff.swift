import Foundation

/// How long to wait after a 429 before asking again (spec › Polling).
///
/// Pure. The schedule is ours; a `Retry-After` header is the server's and wins outright —
/// observed 2026-09-16: the lockout ends at exactly `Retry-After` seconds, and requests
/// made inside it are refused but do not extend it, so there is nothing to gain by
/// second-guessing the header in either direction.
public enum Backoff {
    public static let firstDelay: TimeInterval = 60
    public static let cap: TimeInterval = 600

    /// - Parameter consecutiveRateLimits: how many 429s in a row this one makes (1-based).
    public static func delay(consecutiveRateLimits: Int, retryAfter: TimeInterval?) -> TimeInterval {
        if let retryAfter { return max(0, retryAfter) }
        let doublings = max(0, consecutiveRateLimits - 1)
        return min(firstDelay * pow(2, Double(doublings)), cap)
    }
}
