import Foundation

/// One macOS notification to deliver (see CONTEXT.md › Alert). The title and body are
/// decided here so the executable only has to hand them to the notification center.
public struct Alert: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// Utilization first reached this percentage in the current cycle.
        case threshold(Int)
        /// The 5-hour Window's Reset moved after its Utilization had been ≥ 80.
        case reset
    }

    /// The Window's name as the popover shows it: `5-hour`, `7-day`, or a model name.
    public let window: String
    public let kind: Kind
    /// The Window's rounded Utilization in the Snapshot that fired the Alert.
    public let percent: Int
    /// The Window's Reset in that Snapshot; the body's Time-to-Reset.
    public let resetsAt: Date?
    /// When that Snapshot was fetched; the `now` its Time-to-Reset counts from.
    public let fetchedAt: Date

    public init(window: String, kind: Kind, percent: Int, resetsAt: Date?, fetchedAt: Date) {
        self.window = window
        self.kind = kind
        self.percent = percent
        self.resetsAt = resetsAt
        self.fetchedAt = fetchedAt
    }

    public var title: String {
        switch kind {
        case .threshold(let threshold): return "\(window) window at \(threshold)%"
        case .reset: return "\(window) window reset"
        }
    }

    public var body: String {
        switch kind {
        case .threshold(let threshold):
            let limit = threshold >= 100 ? "Limit reached. " : ""
            guard let resetsAt else { return limit + "No reset time reported." }
            return limit + "Resets in \(TimeToReset.format(reset: resetsAt, now: fetchedAt))."
        case .reset:
            return "Usage is back to \(percent)%."
        }
    }
}

/// What has already fired, per Window, so nothing repeats within a cycle.
public struct AlertState: Equatable, Sendable {
    public struct WindowRecord: Equatable, Sendable {
        /// Identifies the cycle (spec › Alerts): a moved Reset clears `fired`.
        public let resetsAt: Date?
        /// The rounded Utilization last seen; the Reset Alert's "was it ≥ 80" test.
        public let percent: Int
        public let fired: Set<Int>

        public init(resetsAt: Date?, percent: Int, fired: Set<Int>) {
            self.resetsAt = resetsAt
            self.percent = percent
            self.fired = fired
        }
    }

    /// Keyed by Window name. Only the Windows in the last Snapshot are kept.
    public let records: [String: WindowRecord]

    public init(records: [String: WindowRecord] = [:]) {
        self.records = records
    }
}

/// Decides which Alerts a fresh Snapshot fires (spec › Alerts). Pure: the caller keeps the
/// returned state and passes it back with the next Snapshot.
public enum AlertDecision {
    public static let thresholds = [80, 90, 100]
    /// The Utilization at or above which a Reset is worth a notification.
    static let resetAlertThreshold = 80
    /// Why: Anthropic's `resets_at` jitters sub-second between responses (ticket 03). Only
    /// a move larger than this is a new cycle; exact inequality would clear the fired set
    /// on every poll and repeat every Alert.
    static let cycleTolerance: TimeInterval = 60

    public static func decide(previous: AlertState, snapshot: Snapshot) -> (alerts: [Alert], state: AlertState) {
        // Same order as the popover rows: 5-hour, 7-day, then per-model by name. Only the
        // 5-hour Window gets a Reset Alert (spec › Alerts).
        let standard: [(String, Window?)] = [("5-hour", snapshot.fiveHour), ("7-day", snapshot.sevenDay)]
        let perModel = snapshot.perModel.sorted { $0.model < $1.model }.map { ($0.model, Optional($0.window)) }
        var alerts: [Alert] = []
        var records: [String: AlertState.WindowRecord] = [:]
        for (name, window) in standard + perModel {
            guard let window else { continue }
            let (fired, record) = observe(
                window, named: name, previous: previous.records[name], fetchedAt: snapshot.fetchedAt,
                alertsOnReset: name == "5-hour"
            )
            alerts += fired
            records[name] = record
        }
        return (alerts, AlertState(records: records))
    }

    private static func observe(
        _ window: Window, named name: String, previous: AlertState.WindowRecord?, fetchedAt: Date,
        alertsOnReset: Bool
    ) -> (alerts: [Alert], record: AlertState.WindowRecord) {
        let percent = window.percent(remaining: false)
        let reached = thresholds.filter { percent >= $0 }
        func alert(_ kind: Alert.Kind) -> Alert {
            Alert(window: name, kind: kind, percent: percent, resetsAt: window.resetsAt, fetchedAt: fetchedAt)
        }
        // Why: the first sighting of a Window seeds its fired set silently. At launch the
        // user is looking at the readout; "you crossed 80 at some point" is news to nobody.
        guard let previous else {
            return ([], AlertState.WindowRecord(resetsAt: window.resetsAt, percent: percent, fired: Set(reached)))
        }
        let isNewCycle = !isSameCycle(previous.resetsAt, window.resetsAt)
        let alreadyFired = isNewCycle ? [] : previous.fired
        var alerts: [Alert] = []
        if isNewCycle, alertsOnReset, previous.percent >= resetAlertThreshold {
            alerts.append(alert(.reset))
        }
        alerts += reached.filter { !alreadyFired.contains($0) }.map { alert(.threshold($0)) }
        let record = AlertState.WindowRecord(
            resetsAt: window.resetsAt, percent: percent, fired: alreadyFired.union(reached)
        )
        return (alerts, record)
    }

    private static func isSameCycle(_ before: Date?, _ after: Date?) -> Bool {
        switch (before, after) {
        case (nil, nil): return true
        case (let before?, let after?): return abs(after.timeIntervalSince(before)) <= cycleTolerance
        default: return false
        }
    }
}
