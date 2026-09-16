/// What macOS reports for the app's login item. Mirrors `SMAppService.Status` so the core
/// stays free of ServiceManagement; the executable maps one to the other.
public enum LaunchAtLoginStatus: Equatable, Sendable, CaseIterable {
    case notRegistered
    case enabled
    /// Registered, but the user (or an MDM profile) has to approve it in System Settings.
    case requiresApproval
    /// macOS cannot locate the app to register it.
    case notFound
}

/// The Launch at Login toggle's state and the one line that explains it when the
/// checkbox alone would mislead (spec › Popover; ticket 08). Pure: the executable reads the
/// status from `SMAppService` on every popover open and renders this.
public struct LaunchAtLoginRow: Equatable, Sendable {
    public let isOn: Bool
    /// `nil` when the checkbox says it all.
    public let note: String?
    /// Whether the note's fix lives in System Settings › Login Items.
    public let offersSystemSettings: Bool

    public init(isOn: Bool, note: String?, offersSystemSettings: Bool) {
        self.isOn = isOn
        self.note = note
        self.offersSystemSettings = offersSystemSettings
    }

    /// - Parameter failure: why the last register / unregister threw, if it did. The
    ///   checkbox still shows the real status, so a failed change reads as unchanged.
    public static func render(status: LaunchAtLoginStatus, failure: String? = nil) -> LaunchAtLoginRow {
        let isOn = status == .enabled || status == .requiresApproval
        if let failure {
            return LaunchAtLoginRow(isOn: isOn, note: "Couldn't change Launch at Login: \(failure)", offersSystemSettings: false)
        }
        switch status {
        case .enabled, .notRegistered:
            return LaunchAtLoginRow(isOn: isOn, note: nil, offersSystemSettings: false)
        case .requiresApproval:
            return LaunchAtLoginRow(
                isOn: true, note: "Waiting for approval in System Settings › Login Items.", offersSystemSettings: true
            )
        case .notFound:
            return LaunchAtLoginRow(
                isOn: false, note: "macOS can't find this app to register it. Move it to /Applications.",
                offersSystemSettings: false
            )
        }
    }
}
