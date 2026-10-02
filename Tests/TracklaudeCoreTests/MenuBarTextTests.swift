import Foundation
import Testing
import TracklaudeCore

private let now = Date(timeIntervalSince1970: 1_800_000_000)
private let fiveHour = Window(utilization: 42.4, resetsAt: now.addingTimeInterval(2 * 3600 + 14 * 60))

@Test("menu bar shows an em dash when there is no 5-hour Window")
func noFiveHourWindowRendersDash() {
    #expect(MenuBarText.render(window: nil, remaining: false, now: now) == "—")
}

@Test("menu bar shows the 5-hour Utilization and Time-to-Reset")
func usedMode() {
    #expect(MenuBarText.render(window: fiveHour, remaining: false, now: now) == "42% · 2h14m")
}

@Test("remaining mode shows 100 minus the Utilization")
func remainingMode() {
    #expect(MenuBarText.render(window: fiveHour, remaining: true, now: now) == "58% · 2h14m")
}

@Test("a Window without a Reset shows the percentage alone")
func noResetTime() {
    let window = Window(utilization: 42, resetsAt: nil)
    #expect(MenuBarText.render(window: window, remaining: false, now: now) == "42%")
}

// Ticket 05: the label is rendered from the whole state (spec › Menu bar).
private let snapshot = Snapshot(fiveHour: fiveHour, sevenDay: nil, fetchedAt: now)

@Test("polling shows the live readout, not dimmed")
func pollingIsLive() {
    #expect(MenuBarText.render(state: .polling(snapshot), remaining: false, now: now) == MenuBarLabel(text: "42% · 2h14m", isDimmed: false))
    #expect(MenuBarText.render(state: .polling(nil), remaining: false, now: now) == MenuBarLabel(text: "—", isDimmed: false))
}

@Test("stale keeps the last readout, dimmed, with a caution glyph and one word per reason")
func staleIsDimmedWithReason() {
    #expect(MenuBarText.render(state: .stale(snapshot, .offline), remaining: false, now: now) == MenuBarLabel(text: "42% · 2h14m ⚠ offline", isDimmed: true))
    #expect(MenuBarText.render(state: .stale(snapshot, .serverError), remaining: false, now: now) == MenuBarLabel(text: "42% · 2h14m ⚠ error", isDimmed: true))
    #expect(MenuBarText.render(state: .stale(snapshot, .sessionExpired), remaining: false, now: now) == MenuBarLabel(text: "42% · 2h14m ⚠ expired", isDimmed: true))
    #expect(MenuBarText.render(state: .stale(snapshot, .rateLimited), remaining: false, now: now) == MenuBarLabel(text: "42% · 2h14m ⚠ limited", isDimmed: true))
}

// Ticket 16: a 429 on a reading younger than 10 min is not news. Observed 2026-10-03: the
// refusals come whatever this app's rate (5 requests in 17 min, all refused), so the user
// saw "⚠ limited" over a 24 s old reading for no reason they could act on.

@Test("backing off on a reading younger than 10 min shows the live readout, not dimmed")
func backingOffQuietWhileFresh() {
    let recent = Snapshot(fiveHour: fiveHour, sevenDay: nil, fetchedAt: now.addingTimeInterval(-24))
    let state = AppState.backingOff(recent, until: now.addingTimeInterval(60), consecutiveRateLimits: 1)
    #expect(MenuBarText.render(state: state, remaining: false, now: now) == MenuBarLabel(text: "42% · 2h14m", isDimmed: false))
}

@Test("once the reading is 10 min old, backing off reads as rate-limited")
func backingOffIsLimitedWhenOld() {
    let old = Snapshot(fiveHour: fiveHour, sevenDay: nil, fetchedAt: now.addingTimeInterval(-600))
    let state = AppState.backingOff(old, until: now.addingTimeInterval(60), consecutiveRateLimits: 3)
    #expect(MenuBarText.render(state: state, remaining: false, now: now) == MenuBarLabel(text: "42% · 2h14m ⚠ limited", isDimmed: true))
}

@Test("backing off before any reading says so at once")
func backingOffWithoutSnapshot() {
    let state = AppState.backingOff(nil, until: now.addingTimeInterval(60), consecutiveRateLimits: 1)
    #expect(MenuBarText.render(state: state, remaining: false, now: now) == MenuBarLabel(text: "— ⚠ limited", isDimmed: true))
}

@Test("stale with no Snapshot yet still names the reason")
func staleWithoutSnapshot() {
    #expect(MenuBarText.render(state: .stale(nil, .offline), remaining: false, now: now) == MenuBarLabel(text: "— ⚠ offline", isDimmed: true))
}

@Test("remaining mode applies to the stale readout too")
func staleRemainingMode() {
    #expect(MenuBarText.render(state: .stale(snapshot, .offline), remaining: true, now: now).text == "58% · 2h14m ⚠ offline")
}

@Test("signed out asks for a sign-in; signing in shows nothing to read yet")
func signedOutAndSigningIn() {
    #expect(MenuBarText.render(state: .signedOut, remaining: false, now: now) == MenuBarLabel(text: "⚠ sign in", isDimmed: false))
    #expect(MenuBarText.render(state: .signingIn, remaining: false, now: now) == MenuBarLabel(text: "—", isDimmed: false))
}
