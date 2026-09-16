import Foundation
import Testing
import TracklaudeCore

// The scheduler is pure: (state, now, last fetch, trigger) → when to fetch next, or nil.
private let now = Date(timeIntervalSince1970: 1_800_000_000)

private func next(
    _ state: PollState,
    lastFetch: TimeInterval?,
    lastManualRefresh: TimeInterval? = nil,
    trigger: PollTrigger
) -> Date? {
    PollScheduler.nextFetch(
        state: state,
        now: now,
        lastFetch: lastFetch.map { now.addingTimeInterval($0) },
        lastManualRefresh: lastManualRefresh.map { now.addingTimeInterval($0) },
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
    #expect(next(.asleep, lastFetch: -45, trigger: .popoverOpened) == nil)
}

@Test("waking fetches immediately regardless of how recent the last fetch was")
func wakeFetchesNow() {
    #expect(next(.active, lastFetch: -2, trigger: .wake) == now)
    #expect(next(.active, lastFetch: -3600, trigger: .wake) == now)
}

@Test("opening the popover fetches immediately")
func popoverOpenFetchesNow() {
    #expect(next(.active, lastFetch: -2, trigger: .popoverOpened) == now)
    #expect(next(.active, lastFetch: nil, trigger: .popoverOpened) == now)
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
    // The popover just opened and fetched; Refresh is still usable at once.
    #expect(next(.active, lastFetch: -0.5, lastManualRefresh: nil, trigger: .manualRefresh) == now)
    #expect(next(.active, lastFetch: -0.5, lastManualRefresh: -60, trigger: .manualRefresh) == now)
}

@Test("the Refresh button is disabled for 5 s after a manual Refresh and enabled after")
func refreshAvailability() {
    #expect(PollScheduler.isManualRefreshAllowed(now: now, lastManualRefresh: now.addingTimeInterval(-1)) == false)
    #expect(PollScheduler.isManualRefreshAllowed(now: now, lastManualRefresh: now.addingTimeInterval(-5)) == true)
    #expect(PollScheduler.isManualRefreshAllowed(now: now, lastManualRefresh: nil) == true)
}
