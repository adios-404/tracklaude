import Foundation
import Testing
import TracklaudeCore

// Spec › Polling: 60 s → 120 → 240 → capped at 300 s, honouring Retry-After if present.

@Test("consecutive 429s double the delay from 60 s and cap at 300 s")
func backoffDoublesAndCaps() {
    #expect(Backoff.delay(consecutiveRateLimits: 1, retryAfter: nil) == 60)
    #expect(Backoff.delay(consecutiveRateLimits: 2, retryAfter: nil) == 120)
    #expect(Backoff.delay(consecutiveRateLimits: 3, retryAfter: nil) == 240)
    // Ticket 13: an 8–10 min lockout with Refresh greyed out read as a hung app.
    #expect(Backoff.delay(consecutiveRateLimits: 4, retryAfter: nil) == 300)
    #expect(Backoff.delay(consecutiveRateLimits: 50, retryAfter: nil) == 300)
}

@Test("Retry-After wins over the schedule, whether shorter or longer than the step")
func retryAfterTakesPrecedence() {
    // The recorded 429 says 300; the first step would have been 60.
    #expect(Backoff.delay(consecutiveRateLimits: 1, retryAfter: 300) == 300)
    #expect(Backoff.delay(consecutiveRateLimits: 3, retryAfter: 5) == 5)
    // Observed 2026-09-16: the server's lockout is exact; the cap is ours, not theirs.
    #expect(Backoff.delay(consecutiveRateLimits: 1, retryAfter: 900) == 900)
}

@Test("a Retry-After of zero or less falls back to the schedule, never a tight loop")
func nonPositiveRetryAfterUsesSchedule() {
    // Observed 2026-09-17: a 429 with `Retry-After: 0` after an ordinary 30 s poll. Taken
    // literally it re-fetched instantly, got another `0`, and sent 22,000 requests in
    // eight minutes. The server has not said when to come back, so it is our schedule.
    #expect(Backoff.delay(consecutiveRateLimits: 1, retryAfter: 0) == 60)
    #expect(Backoff.delay(consecutiveRateLimits: 2, retryAfter: 0) == 120)
    #expect(Backoff.delay(consecutiveRateLimits: 1, retryAfter: -10) == 60)
}
