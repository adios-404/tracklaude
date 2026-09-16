import Foundation

/// Compact remaining-duration text for a Window's Reset (see CONTEXT.md): `2h14m`, `14m`, `<1m`.
///
/// Pure function of (reset, now). Truncates rather than rounds, so `59m59s` reads `59m` — the
/// readout never claims more time than is actually left.
public enum TimeToReset {
    private static let minute: TimeInterval = 60
    private static let hour: TimeInterval = 3600
    /// Internal: the popover's "add the weekday beyond a day" rule shares this boundary.
    static let day: TimeInterval = 86_400

    public static func format(reset: Date, now: Date) -> String {
        let remaining = reset.timeIntervalSince(now)
        // Why: a Reset in the past is not an error — the next Snapshot will carry the new
        // cycle — so it reads as "imminent" rather than as a negative or fake duration.
        guard remaining >= minute else { return "<1m" }

        let days = Int(remaining / day)
        let hours = Int(remaining.truncatingRemainder(dividingBy: day) / hour)
        let minutes = Int(remaining.truncatingRemainder(dividingBy: hour) / minute)

        if days > 0 { return "\(days)d" + (hours > 0 ? "\(hours)h" : "") }
        if hours > 0 { return "\(hours)h" + (minutes > 0 ? "\(minutes)m" : "") }
        return "\(minutes)m"
    }
}
