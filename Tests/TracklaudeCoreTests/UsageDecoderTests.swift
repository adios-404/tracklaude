import Foundation
import Testing
import TracklaudeCore

private let fetchedAt = Date(timeIntervalSince1970: 1_800_000_000)
// 2026-09-16T18:00:00Z and 2026-09-20T09:00:00Z as epoch seconds.
private let fiveHourReset = Date(timeIntervalSince1970: 1_789_581_600)
private let sevenDayReset = Date(timeIntervalSince1970: 1_789_894_800)

@Test("a normal response yields the 5-hour and 7-day Windows and the fetch time")
func normalResponse() throws {
    let snapshot = try UsageDecoder.decode(try Fixture.data("usage-normal.json"), fetchedAt: fetchedAt)

    #expect(snapshot.fetchedAt == fetchedAt)
    #expect(snapshot.fiveHour == Window(utilization: 42, resetsAt: fiveHourReset))
    #expect(snapshot.sevenDay == Window(utilization: 17.5, resetsAt: sevenDayReset))
}

@Test("weekly_scoped limits with a model display name become per-model Windows, sorted by name")
func perModelWindowsFromLimits() throws {
    let snapshot = try UsageDecoder.decode(try Fixture.data("usage-per-model.json"), fetchedAt: fetchedAt)

    #expect(snapshot.perModel == [
        ModelWindow(model: "Opus", window: Window(utilization: 61, resetsAt: sevenDayReset)),
        ModelWindow(model: "Sonnet", window: Window(utilization: 8, resetsAt: sevenDayReset)),
    ])
}

@Test("legacy seven_day_opus/sonnet fields count as per-model Windows unless they are 0 with no Reset")
func legacyPerModelFields() throws {
    let snapshot = try UsageDecoder.decode(try Fixture.data("usage-legacy-per-model.json"), fetchedAt: fetchedAt)

    #expect(snapshot.perModel == [
        ModelWindow(model: "Sonnet", window: Window(utilization: 3, resetsAt: sevenDayReset)),
    ])
}

@Test("when limits[] already names a model, the legacy field for it is ignored")
func limitsWinOverLegacyFields() throws {
    // usage-per-model.json carries seven_day_sonnet at 3% alongside a weekly_scoped Sonnet at 8%.
    let snapshot = try UsageDecoder.decode(try Fixture.data("usage-per-model.json"), fetchedAt: fetchedAt)

    #expect(snapshot.perModel.filter { $0.model == "Sonnet" }.map(\.window.utilization) == [8])
}

@Test("a response with every Window null is a Snapshot with no Windows, not an error")
func allNullResponse() throws {
    let snapshot = try UsageDecoder.decode(try Fixture.data("usage-all-null.json"), fetchedAt: fetchedAt)

    #expect(snapshot == Snapshot(fiveHour: nil, sevenDay: nil, perModel: [], fetchedAt: fetchedAt))
}

@Test("unknown keys and an unknown limit kind are ignored")
func unknownKeysIgnored() throws {
    let body = Data(#"""
    {"five_hour":{"utilization":5,"resets_at":"2026-09-16T18:00:00Z","surprise":1},
     "brand_new_window":{"utilization":99},
     "limits":[{"kind":"monthly_mystery","percent":50,"scope":{"model":{"display_name":"Haiku"}}}]}
    """#.utf8)

    let snapshot = try UsageDecoder.decode(body, fetchedAt: fetchedAt)

    #expect(snapshot.fiveHour == Window(utilization: 5, resetsAt: fiveHourReset))
    #expect(snapshot.perModel.isEmpty)
}

@Test("an HTML body is reported as not usage JSON")
func htmlBody() throws {
    let body = try Fixture.data("usage-html.html")

    #expect(throws: UsageDecodeError.notUsageJSON) {
        try UsageDecoder.decode(body, fetchedAt: fetchedAt)
    }
}
