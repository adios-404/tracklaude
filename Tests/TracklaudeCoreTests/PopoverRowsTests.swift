import Foundation
import Testing
import TracklaudeCore

// Ticket 06: the popover rows are a pure function of (Snapshot, mode, now, locale).
// en_GB: 24-hour clock with no narrow no-break space, so the expected strings read plainly.
private let now = Date(timeIntervalSince1970: 1_800_000_000) // Fri 2027-01-15 08:00:00 UTC
private let locale = Locale(identifier: "en_GB")
private let utc = TimeZone(identifier: "UTC")!
private let inTwoHours = now.addingTimeInterval(2 * 3600 + 14 * 60)
private let inThreeDays = now.addingTimeInterval(3 * 86_400 + 5 * 3600)

private func render(_ snapshot: Snapshot, remaining: Bool = false) -> PopoverReadout {
    PopoverRows.render(snapshot: snapshot, remaining: remaining, now: now, locale: locale, timeZone: utc)
}

@Test("rows come in the order 5-hour, 7-day, then per-model Windows sorted by name")
func rowOrder() {
    let snapshot = Snapshot(
        fiveHour: Window(utilization: 42.4, resetsAt: inTwoHours),
        sevenDay: Window(utilization: 46, resetsAt: inThreeDays),
        perModel: [
            ModelWindow(model: "Sonnet", window: Window(utilization: 8, resetsAt: inThreeDays)),
            ModelWindow(model: "Opus", window: Window(utilization: 61, resetsAt: inThreeDays)),
        ],
        fetchedAt: now
    )
    guard case .rows(let rows) = render(snapshot) else { Issue.record("expected rows"); return }
    #expect(rows.map(\.name) == ["5-hour", "7-day", "Opus", "Sonnet"])
    #expect(rows.map(\.percent) == [42, 46, 61, 8])
}

@Test("without per-model Windows only the two standard rows appear")
func noPerModelRows() {
    let snapshot = Snapshot(
        fiveHour: Window(utilization: 42, resetsAt: inTwoHours),
        sevenDay: Window(utilization: 46, resetsAt: inThreeDays),
        fetchedAt: now
    )
    guard case .rows(let rows) = render(snapshot) else { Issue.record("expected rows"); return }
    #expect(rows.map(\.name) == ["5-hour", "7-day"])
}

@Test("a Window Anthropic did not report gets no row")
func missingStandardWindowIsSkipped() {
    let snapshot = Snapshot(fiveHour: nil, sevenDay: Window(utilization: 46, resetsAt: inThreeDays), fetchedAt: now)
    guard case .rows(let rows) = render(snapshot) else { Issue.record("expected rows"); return }
    #expect(rows.map(\.name) == ["7-day"])
}

@Test("an all-null Snapshot reads as one honest message, not an empty popover")
func allNullSnapshot() {
    let snapshot = Snapshot(fiveHour: nil, sevenDay: nil, fetchedAt: now)
    #expect(render(snapshot) == .noWindows)
    #expect(PopoverReadout.noWindows.message == "No usage windows reported")
}

private func fiveHourRow(utilization: Double, resetsAt: Date? = inTwoHours, remaining: Bool = false) -> PopoverRow {
    let snapshot = Snapshot(fiveHour: Window(utilization: utilization, resetsAt: resetsAt), sevenDay: nil, fetchedAt: now)
    guard case .rows(let rows) = render(snapshot, remaining: remaining), let row = rows.first else {
        Issue.record("expected one row")
        return PopoverRow(name: "", percent: 0, tone: .normal, resetsIn: nil, resetsAt: nil)
    }
    return row
}

@Test("bar colour: accent below 80, orange from 80, red from 90")
func toneThresholds() {
    #expect(fiveHourRow(utilization: 79).tone == .normal)
    #expect(fiveHourRow(utilization: 80).tone == .warning)
    #expect(fiveHourRow(utilization: 89).tone == .warning)
    #expect(fiveHourRow(utilization: 90).tone == .critical)
}

@Test("bar colour follows the number the user sees: 89.5 reads 90% and is red")
func toneUsesTheDisplayedPercent() {
    let row = fiveHourRow(utilization: 89.5)
    #expect(row.percent == 90)
    #expect(row.tone == .critical)
}

@Test("remaining mode flips the percentage but not the colour: 90% used is red at 10% left")
func remainingModeKeepsTone() {
    let row = fiveHourRow(utilization: 90, remaining: true)
    #expect(row.percent == 10)
    #expect(row.tone == .critical)
}

// now is Fri 2027-01-15 08:00:00 UTC.

@Test("a row shows the relative Time-to-Reset and the absolute time in the locale's short form")
func resetTexts() {
    let row = fiveHourRow(utilization: 42, resetsAt: inTwoHours)
    #expect(row.resetsIn == "resets in 2h14m")
    #expect(row.resetsAt == "at 10:14")
}

@Test("the absolute time gains the weekday only once the Reset is more than 24 h away")
func weekdayBeyondOneDay() {
    let exactlyOneDay = now.addingTimeInterval(86_400)
    #expect(fiveHourRow(utilization: 42, resetsAt: exactlyOneDay).resetsAt == "at 08:00")
    #expect(fiveHourRow(utilization: 42, resetsAt: exactlyOneDay.addingTimeInterval(1)).resetsAt == "at Sat 08:00")
    #expect(fiveHourRow(utilization: 42, resetsAt: inThreeDays).resetsAt == "at Mon 13:00")
}

@Test("the absolute time follows the locale: en_US uses a 12-hour clock")
func absoluteTimeFollowsLocale() {
    let snapshot = Snapshot(fiveHour: Window(utilization: 42, resetsAt: inTwoHours), sevenDay: nil, fetchedAt: now)
    let readout = PopoverRows.render(snapshot: snapshot, remaining: false, now: now, locale: Locale(identifier: "en_US"), timeZone: utc)
    guard case .rows(let rows) = readout else { Issue.record("expected rows"); return }
    // Why: ICU puts a narrow no-break space before AM/PM on current macOS (verified 2026-09-17).
    #expect(rows.first?.resetsAt == "at 10:14\u{202F}AM")
}

@Test("a Window without a Reset shows no reset texts at all")
func noResetTexts() {
    let row = fiveHourRow(utilization: 42, resetsAt: nil)
    #expect(row.resetsIn == nil)
    #expect(row.resetsAt == nil)
}

@Test("remaining mode flips every row's percentage")
func remainingModeFlipsEveryRow() {
    let snapshot = Snapshot(
        fiveHour: Window(utilization: 42, resetsAt: inTwoHours),
        sevenDay: Window(utilization: 46, resetsAt: inThreeDays),
        perModel: [ModelWindow(model: "Opus", window: Window(utilization: 61, resetsAt: inThreeDays))],
        fetchedAt: now
    )
    guard case .rows(let rows) = render(snapshot, remaining: true) else { Issue.record("expected rows"); return }
    #expect(rows.map(\.percent) == [58, 54, 39])
}
