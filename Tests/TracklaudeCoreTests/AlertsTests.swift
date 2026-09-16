import Foundation
import Testing
import TracklaudeCore

// Ticket 07: which Alerts fire is a pure function of (previous AlertState, new Snapshot).
private let now = Date(timeIntervalSince1970: 1_800_000_000)
private let reset = now.addingTimeInterval(2 * 3600 + 14 * 60)

private func snapshot(fiveHour: Double, resetsAt: Date? = reset, fetchedAt: Date = now) -> Snapshot {
    Snapshot(fiveHour: Window(utilization: fiveHour, resetsAt: resetsAt), sevenDay: nil, fetchedAt: fetchedAt)
}

/// Feeds the Snapshots in order and returns the Alerts of the last one.
private func alerts(after snapshots: [Snapshot]) -> [Alert] {
    var state = AlertState()
    var fired: [Alert] = []
    for snapshot in snapshots {
        (fired, state) = AlertDecision.decide(previous: state, snapshot: snapshot)
    }
    return fired
}

@Test("a single crossing of 80 fires the 80 Alert once, naming the Window")
func singleCrossing() {
    let fired = alerts(after: [snapshot(fiveHour: 70), snapshot(fiveHour: 82)])
    #expect(fired == [Alert(window: "5-hour", kind: .threshold(80), percent: 82, resetsAt: reset, fetchedAt: now)])
    #expect(fired.first?.title == "5-hour window at 80%")
    #expect(fired.first?.body == "Resets in 2h14m.")
}

@Test("skipping straight from 70 to 95 fires the 80 and 90 Alerts, in that order")
func skippedThresholdsAllFire() {
    let fired = alerts(after: [snapshot(fiveHour: 70), snapshot(fiveHour: 95)])
    #expect(fired.map(\.kind) == [.threshold(80), .threshold(90)])
}

@Test("a threshold already fired this cycle does not fire again on the next poll")
func noRepeatWithinCycle() {
    let fired = alerts(after: [snapshot(fiveHour: 70), snapshot(fiveHour: 82), snapshot(fiveHour: 84)])
    #expect(fired.isEmpty)
}

@Test("the first Snapshot after launch fires nothing, even above a threshold")
func firstSnapshotIsQuiet() {
    // Why: at launch the user is looking at the readout; a burst of "you crossed 80 and 90
    // at some point" would be news to nobody. Those thresholds count as fired for the cycle.
    let fired = alerts(after: [snapshot(fiveHour: 95)])
    #expect(fired.isEmpty)
    let afterwards = alerts(after: [snapshot(fiveHour: 95), snapshot(fiveHour: 96)])
    #expect(afterwards.isEmpty)
}

private let nextReset = reset.addingTimeInterval(5 * 3600)

@Test("a changed Reset starts a new cycle: the thresholds fire again")
func cycleChangeClearsFiredSet() {
    let fired = alerts(after: [
        snapshot(fiveHour: 70), snapshot(fiveHour: 85),
        snapshot(fiveHour: 5, resetsAt: nextReset), snapshot(fiveHour: 85, resetsAt: nextReset),
    ])
    #expect(fired.map(\.kind) == [.threshold(80)])
}

@Test("a Reset that jitters by under a minute is the same cycle")
func resetJitterIsSameCycle() {
    // Why: Anthropic's resets_at wobbles sub-second between responses (ticket 03); a
    // cycle must not look new on every poll or the Alerts would repeat every 30 s.
    let jittered = reset.addingTimeInterval(45)
    let fired = alerts(after: [snapshot(fiveHour: 70), snapshot(fiveHour: 85), snapshot(fiveHour: 86, resetsAt: jittered)])
    #expect(fired.isEmpty)
}

@Test("the 5-hour Reset Alert fires when the Reset moves after Utilization was ≥ 80")
func resetAlertAfterHighUtilization() {
    let fired = alerts(after: [snapshot(fiveHour: 70), snapshot(fiveHour: 85), snapshot(fiveHour: 3, resetsAt: nextReset)])
    #expect(fired == [Alert(window: "5-hour", kind: .reset, percent: 3, resetsAt: nextReset, fetchedAt: now)])
    #expect(fired.first?.title == "5-hour window reset")
    #expect(fired.first?.body == "Usage is back to 3%.")
}

@Test("no Reset Alert when the previous Utilization was below 80")
func noResetAlertAfterLowUtilization() {
    let fired = alerts(after: [snapshot(fiveHour: 70), snapshot(fiveHour: 79), snapshot(fiveHour: 3, resetsAt: nextReset)])
    #expect(fired.isEmpty)
}

private let weekReset = now.addingTimeInterval(3 * 86_400)

private func snapshot(fiveHour: Double, sevenDay: Double, opus: Double) -> Snapshot {
    Snapshot(
        fiveHour: Window(utilization: fiveHour, resetsAt: reset),
        sevenDay: Window(utilization: sevenDay, resetsAt: weekReset),
        perModel: [ModelWindow(model: "Opus", window: Window(utilization: opus, resetsAt: weekReset))],
        fetchedAt: now
    )
}

@Test("the 7-day and per-model Windows alert independently of the 5-hour one")
func windowsAlertIndependently() {
    let fired = alerts(after: [
        snapshot(fiveHour: 10, sevenDay: 75, opus: 88),
        snapshot(fiveHour: 12, sevenDay: 81, opus: 91),
    ])
    #expect(fired.map(\.title) == ["7-day window at 80%", "Opus window at 90%"])
    #expect(fired.map(\.body) == ["Resets in 3d.", "Resets in 3d."])
}

@Test("only the 5-hour Window gets a Reset Alert")
func onlyFiveHourResets() {
    let before = snapshot(fiveHour: 10, sevenDay: 85, opus: 85)
    let after = Snapshot(
        fiveHour: before.fiveHour, sevenDay: Window(utilization: 1, resetsAt: weekReset.addingTimeInterval(7 * 86_400)),
        perModel: [ModelWindow(model: "Opus", window: Window(utilization: 1, resetsAt: weekReset.addingTimeInterval(7 * 86_400)))],
        fetchedAt: now
    )
    #expect(alerts(after: [before, after]).isEmpty)
}

@Test("reaching 100 says the limit is reached")
func limitReachedBody() {
    let fired = alerts(after: [snapshot(fiveHour: 95), snapshot(fiveHour: 100)])
    #expect(fired.map(\.title) == ["5-hour window at 100%"])
    #expect(fired.map(\.body) == ["Limit reached. Resets in 2h14m."])
}

@Test("a Window reported without a Reset still alerts, with no Time-to-Reset in the body")
func alertsWithoutResetTime() {
    let fired = alerts(after: [snapshot(fiveHour: 70, resetsAt: nil), snapshot(fiveHour: 82, resetsAt: nil)])
    #expect(fired.map(\.title) == ["5-hour window at 80%"])
    #expect(fired.map(\.body) == ["No reset time reported."])
}

@Test("thresholds use the rounded Utilization the popover shows, so the row colour and the Alert agree")
func roundedUtilization() {
    let fired = alerts(after: [snapshot(fiveHour: 70), snapshot(fiveHour: 89.5)])
    #expect(fired.map(\.kind) == [.threshold(80), .threshold(90)])
}
