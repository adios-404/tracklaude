import Foundation
import Testing
import TracklaudeCore

private let fetchedAt = Date(timeIntervalSince1970: 1_800_000_000)
// The recorded Resets, 2026-09-16T20:00:00.83Z and 2026-09-17T03:00:00.83Z, truncated to the second.
private let fiveHourReset = Date(timeIntervalSince1970: 1_789_588_800)
private let sevenDayReset = Date(timeIntervalSince1970: 1_789_614_000)

@Test("a real response yields the 5-hour and 7-day Windows, the reported per-model Window, and the fetch time")
func normalResponse() throws {
    let snapshot = try UsageDecoder.decode(try Fixture.body("usage-normal.http"), fetchedAt: fetchedAt)

    #expect(snapshot.fetchedAt == fetchedAt)
    #expect(snapshot.fiveHour == Window(utilization: 48, resetsAt: fiveHourReset))
    #expect(snapshot.sevenDay == Window(utilization: 46, resetsAt: sevenDayReset))
    // Anthropic reported this one at 0% with a Reset, so it is a real (if idle) Window.
    // Its resets_at has no fractional seconds — the parser must accept both forms.
    #expect(snapshot.perModel == [
        ModelWindow(model: "Fable", window: Window(utilization: 0, resetsAt: sevenDayReset)),
    ])
}

@Test("weekly_scoped limits with a model display name become per-model Windows, sorted by name")
func perModelWindowsFromLimits() throws {
    let snapshot = try UsageDecoder.decode(try Fixture.body("usage-per-model.http"), fetchedAt: fetchedAt)

    #expect(snapshot.perModel.map(\.model) == ["Opus", "Sonnet"])
    #expect(snapshot.perModel.map(\.window.utilization) == [61, 8])
}

@Test("legacy seven_day_opus/sonnet fields count as per-model Windows unless they are 0 with no Reset")
func legacyPerModelFields() throws {
    let snapshot = try UsageDecoder.decode(try Fixture.body("usage-legacy-per-model.http"), fetchedAt: fetchedAt)

    #expect(snapshot.perModel == [
        ModelWindow(model: "Sonnet", window: Window(utilization: 3, resetsAt: sevenDayReset)),
    ])
}

@Test("when limits[] already names a model, the legacy field for it is ignored")
func limitsWinOverLegacyFields() throws {
    // usage-per-model.json carries seven_day_sonnet at 3% alongside a weekly_scoped Sonnet at 8%.
    let snapshot = try UsageDecoder.decode(try Fixture.body("usage-per-model.http"), fetchedAt: fetchedAt)

    #expect(snapshot.perModel.filter { $0.model == "Sonnet" }.map(\.window.utilization) == [8])
}

@Test("a response with every Window null is a Snapshot with no Windows, not an error")
func allNullResponse() throws {
    let snapshot = try UsageDecoder.decode(try Fixture.body("usage-all-null.http"), fetchedAt: fetchedAt)

    #expect(snapshot == Snapshot(fiveHour: nil, sevenDay: nil, perModel: [], fetchedAt: fetchedAt))
}

@Test("unknown keys and an unknown limit kind are ignored")
func unknownKeysIgnored() throws {
    let snapshot = try UsageDecoder.decode(try Fixture.body("usage-unknown-keys.http"), fetchedAt: fetchedAt)

    #expect(snapshot.fiveHour == Window(utilization: 5, resetsAt: Date(timeIntervalSince1970: 1_789_581_600)))
    #expect(snapshot.perModel.isEmpty)
}

@Test("an HTML body is reported as not usage JSON")
func htmlBody() throws {
    let body = try Fixture.body("usage-html.http")

    #expect(throws: UsageDecodeError.notUsageJSON) {
        try UsageDecoder.decode(body, fetchedAt: fetchedAt)
    }
}
