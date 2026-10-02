import Foundation
import Testing
import TracklaudeCore

// Spec › Polling: 60 s → 120 s, then 120 s again, honouring Retry-After if present.

@Test("consecutive 429s wait 60 s, then 120 s from then on")
func backoffDoublesAndCaps() {
    #expect(Backoff.delay(consecutiveRateLimits: 1, retryAfter: nil) == 60)
    #expect(Backoff.delay(consecutiveRateLimits: 2, retryAfter: nil) == 120)
    // Ticket 16: refusals without a Retry-After lasted 1–17 min whatever the app's rate, so
    // a longer wait only delays the first good reading after they stop.
    #expect(Backoff.delay(consecutiveRateLimits: 3, retryAfter: nil) == 120)
    #expect(Backoff.delay(consecutiveRateLimits: 50, retryAfter: nil) == 120)
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
    #expect(Backoff.delay(consecutiveRateLimits: 5, retryAfter: 0) == 120)
    #expect(Backoff.delay(consecutiveRateLimits: 1, retryAfter: -10) == 60)
}
