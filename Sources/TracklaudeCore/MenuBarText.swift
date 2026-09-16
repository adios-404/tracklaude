/// Renders the menu-bar label from the 5-hour Window.
///
/// Pure: takes everything it needs as parameters. The executable only displays the result.
public enum MenuBarText {
    /// Shown when the Snapshot has no 5-hour Window (or there is no Snapshot yet).
    /// An honest "nothing to show" rather than a fake 0%.
    static let noWindow = "—"

    /// - Parameter fiveHour: the 5-hour Window's label, or `nil` when Anthropic reports none.
    ///   Grows into a real Window type in the live-readout ticket.
    public static func render(fiveHour: String?) -> String {
        fiveHour ?? noWindow
    }
}
