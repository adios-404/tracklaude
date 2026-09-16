import Foundation

/// The popover footer's "Updated 12 s ago". Pure; the executable ticks `now` once a second
/// while the popover is open.
public enum UpdatedAgoText {
    static let noSnapshot = "Not updated yet"
    private static let minute = 60
    private static let hour = 3600

    public static func render(fetchedAt: Date?, now: Date) -> String {
        guard let fetchedAt else { return noSnapshot }
        // Why: clamp at zero — a Snapshot stamped slightly ahead of `now` (clock skew,
        // fetch time taken before the render clock) must not read "-3 s ago".
        let seconds = Int(max(0, now.timeIntervalSince(fetchedAt)))
        switch seconds {
        case ..<minute: return "Updated \(seconds) s ago"
        case ..<hour: return "Updated \(seconds / minute) min ago"
        default: return "Updated \(seconds / hour) h ago"
        }
    }
}
