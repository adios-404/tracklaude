import Foundation
import Testing
import TracklaudeCore

// Boundaries from spec › Testing Decisions: 59 s, 60 s, 59 min, 60 min, 24 h, 7 d, past.
private let now = Date(timeIntervalSince1970: 1_800_000_000)

private func format(_ seconds: TimeInterval) -> String {
    TimeToReset.format(reset: now.addingTimeInterval(seconds), now: now)
}

@Test("under a minute reads <1m")
func underAMinute() {
    #expect(format(1) == "<1m")
    #expect(format(59) == "<1m")
    #expect(format(59.9) == "<1m")
}

@Test("a Reset already in the past reads <1m rather than a negative duration")
func pastReset() {
    #expect(format(-3600) == "<1m")
}

@Test("whole minutes under an hour show minutes only")
func minutesOnly() {
    #expect(format(60) == "1m")
    #expect(format(14 * 60 + 30) == "14m")
    #expect(format(59 * 60) == "59m")
}

@Test("an hour or more, under a day, shows hours and minutes")
func hoursAndMinutes() {
    #expect(format(3600) == "1h")
    #expect(format(2 * 3600 + 14 * 60) == "2h14m")
    #expect(format(23 * 3600 + 59 * 60 + 59) == "23h59m")
}

@Test("a day or more shows days and hours, dropping minutes")
func daysAndHours() {
    #expect(format(86_400) == "1d")
    #expect(format(86_400 + 2 * 3600 + 14 * 60) == "1d2h")
    #expect(format(7 * 86_400) == "7d")
}
