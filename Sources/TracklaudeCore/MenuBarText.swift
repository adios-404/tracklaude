import Foundation

/// Renders the menu-bar label from the 5-hour Window: `42% · 2h14m`.
///
/// Pure: takes everything it needs as parameters. The executable only displays the result.
public enum MenuBarText {
    /// Shown when the Snapshot has no 5-hour Window (or there is no Snapshot yet).
    /// An honest "nothing to show" rather than a fake 0%.
    static let noWindow = "—"

    /// - Parameters:
    ///   - fiveHour: the 5-hour Window, or `nil` when Anthropic reports none.
    ///   - remaining: show `100 − utilization` instead of the Utilization.
    public static func render(fiveHour: Window?, remaining: Bool, now: Date) -> String {
        guard let fiveHour else { return noWindow }
        let percent = Int((remaining ? 100 - fiveHour.utilization : fiveHour.utilization).rounded())
        guard let reset = fiveHour.resetsAt else { return "\(percent)%" }
        return "\(percent)% · \(TimeToReset.format(reset: reset, now: now))"
    }
}
