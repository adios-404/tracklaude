import Foundation
import Testing
import TracklaudeCore

// The scheduler is pure: (state, now, last fetch, trigger) → when to fetch next, or nil.
private let now = Date(timeIntervalSince1970: 1_800_000_000)

private func next(
    _ state: PollState,
    lastFetch: TimeInterval?,
    lastManualRefresh: TimeInterval? = nil,
    lastRateLimit: TimeInterval? = nil,
    trigger: PollTrigger
) -> Date? {
    PollScheduler.nextFetch(
        state: state,
        now: now,
        lastFetch: lastFetch.map { now.addingTimeInterval($0) },
        lastManualRefresh: lastManualRefresh.map { now.addingTimeInterval($0) },
        lastRateLimit: lastRateLimit.map { now.addingTimeInterval($0) },
        trigger: trigger
    )
}

@Test("no fetch is ever scheduled while signed out, whatever the trigger", arguments: PollTrigger.allCases)
func signedOutNeverFetches(trigger: PollTrigger) {
    #expect(next(.signedOut, lastFetch: nil, trigger: trigger) == nil)
    #expect(next(.signedOut, lastFetch: -600, trigger: trigger) == nil)
}

@Test("steady state: the next fetch is 30 s after the last one")
func steadyStateIsThirtySeconds() {
    #expect(next(.active, lastFetch: 0, trigger: .timer) == now.addingTimeInterval(30))
    #expect(next(.active, lastFetch: -12, trigger: .timer) == now.addingTimeInterval(18))
}

@Test("polling starts with an immediate fetch when nothing has been fetched yet")
func firstFetchIsImmediate() {
    #expect(next(.active, lastFetch: nil, trigger: .timer) == now)
}

@Test("a cadence slot that has already passed is fetched now, not in the past")
func overdueSlotFetchesNow() {
    #expect(next(.active, lastFetch: -45, trigger: .timer) == now)
}

@Test("while the Mac sleeps no fetch is scheduled, even an overdue one")
func sleepSuspendsTheTimer() {
    #expect(next(.asleep, lastFetch: -45, trigger: .timer) == nil)
    #expect(next(.asleep, lastFetch: -45, trigger: .wake) == nil)
}

@Test("waking fetches immediately regardless of how recent the last fetch was")
func wakeFetchesNow() {
    #expect(next(.active, lastFetch: -2, trigger: .wake) == now)
    #expect(next(.active, lastFetch: -3600, trigger: .wake) == now)
}

@Test("manual Refresh fetches immediately once the 5 s cooldown has passed")
func manualRefreshOutsideCooldown() {
    #expect(next(.active, lastFetch: -5, lastManualRefresh: -5, trigger: .manualRefresh) == now)
    #expect(next(.active, lastFetch: -20, lastManualRefresh: -20, trigger: .manualRefresh) == now)
    #expect(next(.active, lastFetch: nil, lastManualRefresh: nil, trigger: .manualRefresh) == now)
}

@Test("manual Refresh inside the cooldown does not fetch; the regular slot stands")
func manualRefreshInsideCooldown() {
    #expect(next(.active, lastFetch: -1, lastManualRefresh: -1, trigger: .manualRefresh) == now.addingTimeInterval(29))
    #expect(next(.active, lastFetch: -4.9, lastManualRefresh: -4.9, trigger: .manualRefresh) == now.addingTimeInterval(25.1))
}

@Test("the cooldown counts from the last manual Refresh, not from a fetch the popover or timer issued")
func cooldownIgnoresAutomaticFetches() {
    // The timer just fetched; Refresh is still usable at once.
    #expect(next(.active, lastFetch: -0.5, lastManualRefresh: nil, trigger: .manualRefresh) == now)
    #expect(next(.active, lastFetch: -0.5, lastManualRefresh: -60, trigger: .manualRefresh) == now)
}

@Test("the Refresh button is disabled for 5 s after a manual Refresh and enabled after")
func refreshAvailability() {
    #expect(PollScheduler.isManualRefreshAllowed(state: .active, now: now, lastManualRefresh: now.addingTimeInterval(-1)) == false)
    #expect(PollScheduler.isManualRefreshAllowed(state: .active, now: now, lastManualRefresh: now.addingTimeInterval(-5)) == true)
    #expect(PollScheduler.isManualRefreshAllowed(state: .active, now: now, lastManualRefresh: nil) == true)
}

// Ticket 05: backing off after a 429.

@Test("while backing off, every trigger waits for the lockout to end — a Refresh must not spend a request that will be refused", arguments: PollTrigger.allCases)
func backingOffWaitsForUntil(trigger: PollTrigger) {
    let until = now.addingTimeInterval(300)
    #expect(next(.backingOff(until: until), lastFetch: -2, lastManualRefresh: -60, trigger: trigger) == until)
}

@Test("a lockout that ended while the Mac slept is fetched now on wake, not in the past")
func expiredBackoffFetchesNow() {
    #expect(next(.backingOff(until: now.addingTimeInterval(-10)), lastFetch: -400, trigger: .wake) == now)
    #expect(next(.backingOff(until: now.addingTimeInterval(-10)), lastFetch: -400, trigger: .timer) == now)
}

@Test("the Refresh button is disabled for the whole lockout, even outside the 5 s cooldown")
func refreshDisabledWhileBackingOff() {
    #expect(PollScheduler.isManualRefreshAllowed(state: .backingOff(until: now.addingTimeInterval(1)), now: now, lastManualRefresh: nil) == false)
    #expect(PollScheduler.isManualRefreshAllowed(state: .active, now: now, lastManualRefresh: nil) == true)
    #expect(PollScheduler.isManualRefreshAllowed(state: .active, now: now, lastManualRefresh: now.addingTimeInterval(-1)) == false)
}

// Ticket 13: the usage endpoint's budget (~20–25 requests per 10 min) is per account and
// shared; at 30 s this app alone spends 20. Observed 2026-10-02: snapping back to 30 s
// after one success drew the next 429 within a minute, for hours.

@Test("for 30 min after a 429 the cadence is 120 s, not 30 s")
func cadenceSlowsAfterRateLimit() {
    #expect(next(.active, lastFetch: 0, lastRateLimit: -60, trigger: .timer) == now.addingTimeInterval(120))
    #expect(next(.active, lastFetch: -12, lastRateLimit: -(30 * 60 - 1), trigger: .timer) == now.addingTimeInterval(108))
}

@Test("30 min after the last 429 the cadence is back to 30 s")
func cadenceRecoversAfterQuietPeriod() {
    #expect(next(.active, lastFetch: 0, lastRateLimit: -30 * 60, trigger: .timer) == now.addingTimeInterval(30))
    #expect(next(.active, lastFetch: 0, lastRateLimit: -7200, trigger: .timer) == now.addingTimeInterval(30))
}

@Test("the slower cadence never delays a fetch the user asked for", arguments: [PollTrigger.wake, .manualRefresh])
func slowCadenceKeepsUserTriggersImmediate(trigger: PollTrigger) {
    #expect(next(.active, lastFetch: -2, lastRateLimit: -60, trigger: trigger) == now)
}

@Test("a Refresh inside its 5 s cooldown during the slowdown keeps the slowed slot")
func manualCooldownDuringSlowdown() {
    #expect(next(.active, lastFetch: -1, lastManualRefresh: -1, lastRateLimit: -60, trigger: .manualRefresh) == now.addingTimeInterval(119))
}
