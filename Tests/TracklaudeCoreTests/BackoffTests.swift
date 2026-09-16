import Foundation
import Testing
import TracklaudeCore

// Spec › Polling: 60 s → 120 → 240 → capped at 600 s, honouring Retry-After if present.

@Test("consecutive 429s double the delay from 60 s and cap at 600 s")
func backoffDoublesAndCaps() {
    #expect(Backoff.delay(consecutiveRateLimits: 1, retryAfter: nil) == 60)
    #expect(Backoff.delay(consecutiveRateLimits: 2, retryAfter: nil) == 120)
    #expect(Backoff.delay(consecutiveRateLimits: 3, retryAfter: nil) == 240)
    #expect(Backoff.delay(consecutiveRateLimits: 4, retryAfter: nil) == 480)
    #expect(Backoff.delay(consecutiveRateLimits: 5, retryAfter: nil) == 600)
    #expect(Backoff.delay(consecutiveRateLimits: 50, retryAfter: nil) == 600)
}

@Test("Retry-After wins over the schedule, whether shorter or longer than the step")
func retryAfterTakesPrecedence() {
    // The recorded 429 says 300; the first step would have been 60.
    #expect(Backoff.delay(consecutiveRateLimits: 1, retryAfter: 300) == 300)
    #expect(Backoff.delay(consecutiveRateLimits: 3, retryAfter: 5) == 5)
    // Observed 2026-09-16: the server's lockout is exact; the cap is ours, not theirs.
    #expect(Backoff.delay(consecutiveRateLimits: 1, retryAfter: 900) == 900)
}

@Test("a nonsensical Retry-After never schedules a fetch in the past")
func retryAfterIsClampedAtZero() {
    #expect(Backoff.delay(consecutiveRateLimits: 1, retryAfter: -10) == 0)
}
