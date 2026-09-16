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
