import Foundation
import os
import ServiceManagement
import TracklaudeCore

/// The app's own login item, through `SMAppService.mainApp` (spec › user story 32).
/// Untested by decision (spec › Testing Decisions): like the Keychain, the real service
/// is covered by the manual check on the app. The core's `LaunchAtLoginRow` decides what
/// the status means to the user.
@MainActor
struct LoginItem {
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "tracklaude", category: "login-item")

    /// What macOS reports right now. Asked on every popover open, so a change made in
    /// System Settings › Login Items shows without a relaunch.
    var status: LaunchAtLoginStatus {
        // Why: outside a bundle (`swift run`) there is no app for macOS to register; the
        // service reports `notFound` there anyway, but say so without asking it.
        guard Bundle.main.bundleIdentifier != nil else { return .notFound }
        switch SMAppService.mainApp.status {
        case .notRegistered: return .notRegistered
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        case .notFound: return .notFound
        @unknown default: return .notFound
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
        Self.log.notice("Launch at Login \(enabled ? "registered" : "unregistered", privacy: .public); status \(String(describing: status), privacy: .public)")
    }

    /// System Settings › General › Login Items, where a `requiresApproval` item is approved.
    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
