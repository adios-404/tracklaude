import Foundation

/// What the menu bar shows. `isDimmed` is decided here, not in the view, so a test can
/// assert it (spec › Menu bar: Stale is the same text in the secondary label colour).
public struct MenuBarLabel: Equatable, Sendable {
    public let text: String
    public let isDimmed: Bool

    public init(text: String, isDimmed: Bool) {
        self.text = text
        self.isDimmed = isDimmed
    }
}

/// Renders the menu-bar label from the 5-hour Window: `42% · 2h14m`, and from the app
/// state: `42% · 2h14m ⚠ offline`, `⚠ sign in`.
///
/// Pure: takes everything it needs as parameters. The executable only displays the result.
public enum MenuBarText {
    /// Shown when the Snapshot has no 5-hour Window (or there is no Snapshot yet).
    /// An honest "nothing to show" rather than a fake 0%.
    static let noWindow = "—"
    static let signedOut = "⚠ sign in"
    static let caution = "⚠"

    public static func render(state: AppState, remaining: Bool, now: Date) -> MenuBarLabel {
        switch state {
        case .signedOut:
            return MenuBarLabel(text: signedOut, isDimmed: false)
        case .signingIn:
            return MenuBarLabel(text: noWindow, isDimmed: false)
        case .polling(let snapshot):
            return MenuBarLabel(text: render(window: snapshot?.fiveHour, remaining: remaining, now: now), isDimmed: false)
        case .stale(let snapshot, let reason):
            return stale(snapshot, reason, remaining: remaining, now: now)
        case .backingOff(let snapshot, _, _):
            guard state.staleReason(now: now) != nil else {
                return MenuBarLabel(text: render(window: snapshot?.fiveHour, remaining: remaining, now: now), isDimmed: false)
            }
            return stale(snapshot, .rateLimited, remaining: remaining, now: now)
        }
    }

    private static func stale(_ snapshot: Snapshot?, _ reason: StaleReason, remaining: Bool, now: Date) -> MenuBarLabel {
        let readout = render(window: snapshot?.fiveHour, remaining: remaining, now: now)
        return MenuBarLabel(text: "\(readout) \(caution) \(word(for: reason))", isDimmed: true)
    }

    /// - Parameters:
    ///   - window: the Window to show — the 5-hour one in the menu bar — or `nil` when
    ///     Anthropic reports none.
    ///   - remaining: show `100 − utilization` instead of the Utilization.
    public static func render(window: Window?, remaining: Bool, now: Date) -> String {
        guard let window else { return noWindow }
        let percent = window.percent(remaining: remaining)
        guard let reset = window.resetsAt else { return "\(percent)%" }
        return "\(percent)% · \(TimeToReset.format(reset: reset, now: now))"
    }

    /// The one word after the caution glyph (spec › Menu bar).
    static func word(for reason: StaleReason) -> String {
        switch reason {
        case .offline: return "offline"
        case .rateLimited: return "limited"
        case .sessionExpired: return "expired"
        case .serverError: return "error"
        }
    }
}
