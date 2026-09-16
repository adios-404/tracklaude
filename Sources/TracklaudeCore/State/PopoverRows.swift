import Foundation

/// One line of the popover: a Window's name and what the user reads about it.
public struct PopoverRow: Equatable, Sendable, Identifiable {
    /// The bar's colour band (spec › Popover: ≥ 90 red, ≥ 80 orange, else accent).
    public enum Tone: Equatable, Sendable {
        case normal, warning, critical
    }

    public let name: String
    /// Names are unique within a Snapshot: two fixed ones plus model display names.
    public var id: String { name }
    /// The percentage shown — Utilization, or `100 − utilization` in remaining mode.
    public let percent: Int
    /// Decided by Utilization, never by the flipped number: 10 % left is as red as 90 % used.
    public let tone: Tone
    /// `resets in 2h14m`; `nil` when Anthropic reports the Window without a Reset.
    public let resetsIn: String?
    /// `at 3:45 PM` in the locale's short time, with the weekday once more than 24 h away.
    public let resetsAt: String?

    public init(name: String, percent: Int, tone: Tone, resetsIn: String?, resetsAt: String?) {
        self.name = name
        self.percent = percent
        self.tone = tone
        self.resetsIn = resetsIn
        self.resetsAt = resetsAt
    }
}

/// What the popover's usage section shows for a Snapshot.
public enum PopoverReadout: Equatable, Sendable {
    case rows([PopoverRow])
    /// The Snapshot decoded but named no Window at all (the all-null fixture): say so
    /// rather than show an empty popover.
    case noWindows

    /// The one line shown for `.noWindows`.
    public static let noWindowsMessage = "No usage windows reported"
}

/// Builds the popover rows from a Snapshot (spec › Popover). Pure: locale and time zone
/// are parameters so a test can pin the absolute-time text.
public enum PopoverRows {
    public static func render(
        snapshot: Snapshot, remaining: Bool, now: Date, locale: Locale, timeZone: TimeZone
    ) -> PopoverReadout {
        let standard: [(String, Window?)] = [("5-hour", snapshot.fiveHour), ("7-day", snapshot.sevenDay)]
        let perModel = snapshot.perModel
            .sorted { $0.model < $1.model }
            .map { ($0.model, Optional($0.window)) }
        let rows = (standard + perModel).compactMap { name, window -> PopoverRow? in
            guard let window else { return nil }
            return PopoverRow(
                name: name,
                percent: window.percent(remaining: remaining),
                tone: tone(for: window),
                resetsIn: window.resetsAt.map { "resets in \(TimeToReset.format(reset: $0, now: now))" },
                resetsAt: window.resetsAt.map { "at \(absolute($0, now: now, locale: locale, timeZone: timeZone))" }
            )
        }
        return rows.isEmpty ? .noWindows : .rows(rows)
    }

    /// The locale's short time (`3:45 PM`, `15:45`); the weekday is added only when the
    /// Reset is more than a day away, when the time alone would be ambiguous.
    private static func absolute(_ reset: Date, now: Date, locale: Locale, timeZone: TimeZone) -> String {
        let time = Date.FormatStyle(locale: locale, timeZone: timeZone).hour().minute()
        let isBeyondOneDay = reset.timeIntervalSince(now) > TimeToReset.day
        return reset.formatted(isBeyondOneDay ? time.weekday(.abbreviated) : time)
    }

    private static let warningThreshold = 80
    private static let criticalThreshold = 90

    /// Why: banded on the rounded Utilization, not the raw one, so a row that reads "90%"
    /// is never orange — the colour and the number the user sees always agree.
    private static func tone(for window: Window) -> PopoverRow.Tone {
        let used = window.percent(remaining: false)
        if used >= criticalThreshold { return .critical }
        if used >= warningThreshold { return .warning }
        return .normal
    }
}
