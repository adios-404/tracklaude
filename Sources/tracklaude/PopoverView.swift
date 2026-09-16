import SwiftUI
import TracklaudeCore

/// The popover shown on click: the banner (when something is wrong), a row per Window,
/// the used ↔ remaining toggle, the Alerts toggle, and the footer.
struct PopoverView: View {
    @Bindable var model: AppModel

    private static let width: CGFloat = 300

    var body: some View {
        // Why: the footer's "Updated N s ago", the Refresh cooldown and the rate-limit
        // countdown all need a clock that ticks while the popover is open. TimelineView
        // supplies one for free and stops when the popover closes; nothing in the model has
        // to run a one-second timer.
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 10) {
                if let banner = PopoverBanner.render(state: model.state, signInFailure: model.signInFailure, now: context.date) {
                    bannerView(banner)
                }
                usageSection(now: context.date)
                if model.snapshot != nil {
                    modeToggle
                }
                alertsToggle
                Divider()
                footer(now: context.date)
            }
        }
        .padding(12)
        .frame(width: Self.width)
        // MenuBarExtra rebuilds the content view on each open, so this fires per open.
        .onAppear {
            model.poll(.popoverOpened)
            model.refreshAlertPermission()
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

    private func footer(now: Date) -> some View {
        HStack {
            Text(UpdatedAgoText.render(fetchedAt: model.snapshot?.fetchedAt, now: now))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Spacer()
            if model.canRefresh {
                Button("Refresh") { model.refresh() }
                    .disabled(!model.isRefreshAllowed(now: now))
                    .keyboardShortcut("r")
            }
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
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
                isStale: model.state.staleReason != nil
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
            HStack(alignment: .firstTextBaseline) {
                Label(problem, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Open System Settings") { NSWorkspace.shared.open(AlertNotifier.systemSettingsURL) }
                    .controlSize(.small)
            }
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
