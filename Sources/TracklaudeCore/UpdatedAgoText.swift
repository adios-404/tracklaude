import Foundation

/// The popover footer's "Updated 12 s ago". Pure; the executable ticks `now` once a second
/// while the popover is open.
public enum UpdatedAgoText {
    static let noSnapshot = "Not updated yet"

    public static func render(fetchedAt: Date?, now: Date) -> String {
        guard let fetchedAt else { return noSnapshot }
        // Why: clamp at zero — a Snapshot stamped slightly ahead of `now` (clock skew,
        // fetch time taken before the render clock) must not read "-3 s ago".
        let seconds = Int(max(0, now.timeIntervalSince(fetchedAt)))
        switch seconds {
        case ..<60: return "Updated \(seconds) s ago"
        case ..<3600: return "Updated \(seconds / 60) min ago"
        default: return "Updated \(seconds / 3600) h ago"
        }
    }
}
