import Foundation
import os
import TracklaudeCore
import UserNotifications

/// Where the user stands with macOS notification permission for this app.
enum AlertPermission: Equatable {
    /// Never asked, or the prompt was dismissed without an answer.
    case undetermined
    case granted
    case denied
}

/// Delivers Alerts through `UNUserNotificationCenter` (spec › Alerts). Untested by
/// decision (spec › Testing Decisions): the real notification center, like the real
/// Keychain, is covered by the manual check on the app.
@MainActor
final class AlertNotifier {
    /// Verified 2026-09-17 on macOS 27: opens System Settings › Notifications.
    static let systemSettingsURL = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!

    /// `nil` outside an app bundle, where `UNUserNotificationCenter.current()` traps.
    private let center: UNUserNotificationCenter?
    private let presenter = ForegroundPresenter()
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "tracklaude", category: "alerts")

    init() {
        // Why: the notification center needs a bundle proxy for the process; a bare
        // `.build/release/tracklaude` has none and `current()` aborts. Only the .app notifies.
        center = Bundle.main.bundleIdentifier == nil ? nil : .current()
        center?.delegate = presenter
    }

    // Why: the callback forms throughout, not the async ones. CI's Swift 6.0 treats every
    // `await center.…` as sending the non-Sendable center off the main actor and refuses;
    // with continuations only Sendable values (a status, an error) cross. Swift 6.2 accepts both.

    /// Asks once; macOS remembers the answer, so calling this on every enable is harmless.
    func requestPermission() async -> AlertPermission {
        guard let center else { return .denied }
        let failure: (any Error)? = await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound]) { _, error in continuation.resume(returning: error) }
        }
        if let failure {
            Self.log.error("Notification permission request failed: \(failure.localizedDescription, privacy: .public)")
        }
        return await permission()
    }

    func permission() async -> AlertPermission {
        guard let center else { return .denied }
        let status = await withCheckedContinuation { continuation in
            center.getNotificationSettings { continuation.resume(returning: $0.authorizationStatus) }
        }
        switch status {
        case .authorized, .provisional: return .granted
        case .denied: return .denied
        case .notDetermined: return .undetermined
        @unknown default: return .denied
        }
    }

    func deliver(_ alert: Alert) async {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        let failure: (any Error)? = await withCheckedContinuation { continuation in
            center.add(request) { error in continuation.resume(returning: error) }
        }
        if let failure {
            Self.log.error("Could not deliver \(alert.title, privacy: .public): \(failure.localizedDescription, privacy: .public)")
        } else {
            Self.log.notice("Delivered: \(alert.title, privacy: .public)")
        }
    }
}

/// Why: while the popover is open the app is frontmost, and macOS hides a frontmost app's
/// notifications unless its delegate asks for them. An Alert that fires while the user is
/// looking at the popover should still show.
private final class ForegroundPresenter: NSObject, UNUserNotificationCenterDelegate, Sendable {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
