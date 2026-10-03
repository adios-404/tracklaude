import AppKit
import Observation
import TracklaudeCore

// Stand-ins for the app's adapters, so PopoverView.swift (a symlink to the app's own file)
// compiles here unchanged. Only the surface PopoverView reads; nothing here does I/O.

enum AlertPermission: Equatable { case undetermined, granted, denied }

enum AlertNotifier {
    static let systemSettingsURL = URL(string: "x-apple.systempreferences:")!
}

@Observable
@MainActor
final class AppModel {
    var state: AppState
    var signInFailure: String?
    var signOutFailure: String?
    var showsRemaining = false
    var alertsEnabled = true
    var alertPermission: AlertPermission = .granted
    var launchAtLoginStatus: LaunchAtLoginStatus = .enabled
    var launchAtLoginFailure: String?

    init(state: AppState) { self.state = state }

    var snapshot: Snapshot? { state.lastSnapshot }
    var canRefresh: Bool { state.isSignedIn }
    func isRefreshAllowed(now: Date) -> Bool { true }
    func refresh() {}
    func signOut() {}
    func perform(_ action: PopoverBanner.Action) {}
    func setLaunchAtLogin(_ enabled: Bool) {}
    func openLoginItemsSettings() {}
    func refreshAlertPermission() {}
    func refreshLaunchAtLogin() {}
}
