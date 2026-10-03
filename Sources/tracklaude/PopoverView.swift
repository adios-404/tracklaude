import SwiftUI
import TracklaudeCore

/// The popover shown on click: the banner (when something is wrong), a row per Window,
/// the used ↔ remaining toggle, the two settings toggles, and the footer.
struct PopoverView: View {
    @Bindable var model: AppModel

    /// Why 320 (ticket 18): the footer's one line (age, Refresh, Sign out, Quit at `.small`)
    /// measured 300.5 pt for "Updated 13 s ago" and 312.5 pt for "Updated 59 min ago", the
    /// longest it says (2026-10-03). At 300 every age of 10 s or more read "Updated 13 s a…".
    private static let width: CGFloat = 320

    var body: some View {
        // Why: the footer's "Updated N s ago", the Refresh cooldown and the rate-limit
        // countdown all need a clock that ticks while the popover is open. TimelineView
        // supplies one for free and stops when the popover closes; nothing in the model has
        // to run a one-second timer.
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 10) {
                if let banner = PopoverBanner.render(
                    state: model.state, signInFailure: model.signInFailure,
                    signOutFailure: model.signOutFailure, now: context.date
                ) {
                    bannerView(banner)
                }
                usageSection(now: context.date)
                if model.snapshot != nil {
                    modeToggle
                }
                launchAtLoginToggle
                alertsToggle
                Divider()
                footer(now: context.date)
            }
        }
        .padding(12)
        .frame(width: Self.width)
        // MenuBarExtra rebuilds the content view on each open, so this fires per open.
        // Why no fetch here (ticket 17): the reading is at most 30 s old, every open spent a
        // request from a budget that refuses checks anyway, and a refusal landing as the
        // popover opened was what the owner kept seeing. Refresh is the explicit way.
        .onAppear {
            model.refreshAlertPermission()
            model.refreshLaunchAtLogin()
        }
    }

    /// The plain-English reason and the one button that fixes it (spec › Popover).
    private func bannerView(_ banner: PopoverBanner) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Label {
                Text(banner.message)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "exclamationmark.triangle")
            }
            .foregroundStyle(.secondary)
            Spacer()
            if let action = banner.action {
                Button(action.title) { model.perform(action) }
            }
        }
    }

    /// One line (ticket 08): the Snapshot's age, then Refresh · Sign out · Quit. The two
    /// toggles sit above the divider, each with room for its own note line.
    private func footer(now: Date) -> some View {
        HStack(spacing: 6) {
            Text(UpdatedAgoText.render(fetchedAt: model.snapshot?.fetchedAt, now: now))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
            Spacer(minLength: 0)
            if model.canRefresh {
                Button("Refresh") { model.refresh() }
                    .disabled(!model.isRefreshAllowed(now: now))
                    .keyboardShortcut("r")
            }
            if model.state.isSignedIn {
                Button("Sign out") { model.signOut() }
            }
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .controlSize(.small)
    }

    /// Launch at Login (spec › user story 32). Off by default; the checkbox shows what macOS
    /// reports, so "waiting for approval" still reads as on with a line saying where to approve.
    @ViewBuilder
    private var launchAtLoginToggle: some View {
        let row = LaunchAtLoginRow.render(status: model.launchAtLoginStatus, failure: model.launchAtLoginFailure)
        Toggle("Launch at Login", isOn: Binding(get: { row.isOn }, set: { model.setLaunchAtLogin($0) }))
            .toggleStyle(.checkbox)
        if let note = row.note {
            noteLine(note, systemSettings: row.offersSystemSettings ? { model.openLoginItemsSettings() } : nil)
        }
    }

    /// A caption under a toggle, with the System Settings button when that is where the fix is.
    private func noteLine(_ text: String, systemSettings: (() -> Void)?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Label(text, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            if let systemSettings {
                Button("Open System Settings", action: systemSettings)
                    .controlSize(.small)
            }
        }
    }

    /// The rows for the last Snapshot — kept, dimmed, while Stale.
    @ViewBuilder
    private func usageSection(now: Date) -> some View {
        if let snapshot = model.snapshot {
            UsageRowsView(
                readout: PopoverRows.render(
                    snapshot: snapshot, remaining: model.showsRemaining, now: now,
                    locale: .autoupdatingCurrent, timeZone: .autoupdatingCurrent
                ),
                isStale: model.state.staleReason(now: now) != nil
            )
        } else if case .polling = model.state {
            Text("Fetching usage…")
                .foregroundStyle(.secondary)
        }
    }

    /// Alerts on ↔ off (spec › Alerts). While macOS has not granted permission the toggle
    /// alone would lie — say so, and point at the one place that can fix it.
    @ViewBuilder
    private var alertsToggle: some View {
        Toggle("Alerts at 80, 90 and 100%", isOn: $model.alertsEnabled)
            .toggleStyle(.checkbox)
        if model.alertsEnabled, let problem = Self.permissionProblem(model.alertPermission) {
            noteLine(problem) { NSWorkspace.shared.open(AlertNotifier.systemSettingsURL) }
        }
    }

    private static func permissionProblem(_ permission: AlertPermission) -> String? {
        switch permission {
        case .granted: return nil
        case .denied: return "Notifications are off for tracklaude."
        case .undetermined: return "Notifications are not allowed yet."
        }
    }

    /// Used ↔ remaining (spec › Popover). The menu bar flips with it.
    private var modeToggle: some View {
        Picker("Mode", selection: $model.showsRemaining) {
            Text("Used").tag(false)
            Text("Remaining").tag(true)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}
