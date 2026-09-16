import SwiftUI
import TracklaudeCore

/// The popover shown on click: sign-in status, a bare usage readout, and the footer.
struct PopoverView: View {
    let model: AppModel

    var body: some View {
        // Why: the footer's "Updated N s ago" and the Refresh cooldown both need a clock that
        // ticks while the popover is open. TimelineView supplies one for free and stops when
        // the popover closes; nothing in the model has to run a one-second timer.
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 10) {
                authSection(now: context.date)
                Divider()
                footer(now: context.date)
            }
        }
        .padding(12)
        .frame(minWidth: 220)
        // MenuBarExtra rebuilds the content view on each open, so this fires per open.
        .onAppear { model.poll(.popoverOpened) }
    }

    private func footer(now: Date) -> some View {
        HStack {
            Text(UpdatedAgoText.render(fetchedAt: model.snapshot?.fetchedAt, now: now))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Spacer()
            if model.auth == .signedIn {
                Button("Refresh") { model.refresh() }
                    .disabled(!PollScheduler.isManualRefreshAllowed(now: now, lastFetch: model.lastFetch))
                    .keyboardShortcut("r")
            }
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }

    /// A bare readout of the Snapshot; the full row layout is ticket 06.
    @ViewBuilder
    private func usageSection(now: Date) -> some View {
        if let snapshot = model.snapshot {
            windowLine("5-hour", snapshot.fiveHour, now: now)
            windowLine("7-day", snapshot.sevenDay, now: now)
            ForEach(snapshot.perModel, id: \.model) { entry in
                windowLine(entry.model, entry.window, now: now)
            }
        } else if let failure = model.fetchFailure {
            Label("Usage unavailable", systemImage: "exclamationmark.triangle")
            Text(failure)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text("Fetching usage…")
                .foregroundStyle(.secondary)
        }
    }

    private func windowLine(_ name: String, _ window: TracklaudeCore.Window?, now: Date) -> some View {
        HStack {
            Text(name)
            Spacer()
            Text(MenuBarText.render(window: window, remaining: false, now: now))
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private func authSection(now: Date) -> some View {
        switch model.auth {
        case .signedOut:
            Button("Sign in with Claude") { model.signIn() }
        case .signingIn:
            Text("Finish signing in in your browser…")
                .foregroundStyle(.secondary)
            Button("Cancel") { model.cancelSignIn() }
        case .signedIn:
            Label("Signed in", systemImage: "checkmark.circle")
            usageSection(now: now)
        case .failed(let reason):
            Label("Sign-in failed", systemImage: "exclamationmark.triangle")
            Text(reason)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Try again") { model.signIn() }
        }
    }
}
