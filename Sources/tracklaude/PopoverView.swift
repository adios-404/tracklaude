import SwiftUI
import TracklaudeCore

/// The popover shown on click: sign-in status and Quit.
struct PopoverView: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            authSection
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(12)
        .frame(minWidth: 220)
    }

    /// A bare readout of the Snapshot; the full row layout is ticket 06.
    @ViewBuilder
    private var usageSection: some View {
        if let snapshot = model.snapshot {
            windowLine("5-hour", snapshot.fiveHour)
            windowLine("7-day", snapshot.sevenDay)
            ForEach(snapshot.perModel, id: \.model) { entry in
                windowLine(entry.model, entry.window)
            }
            Text("Fetched \(snapshot.fetchedAt.formatted(date: .omitted, time: .standard))")
                .font(.caption)
                .foregroundStyle(.secondary)
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

    private func windowLine(_ name: String, _ window: TracklaudeCore.Window?) -> some View {
        HStack {
            Text(name)
            Spacer()
            Text(MenuBarText.render(window: window, remaining: false, now: Date()))
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private var authSection: some View {
        switch model.auth {
        case .signedOut:
            Button("Sign in with Claude") { model.signIn() }
        case .signingIn:
            Text("Finish signing in in your browser…")
                .foregroundStyle(.secondary)
            Button("Cancel") { model.cancelSignIn() }
        case .signedIn:
            Label("Signed in", systemImage: "checkmark.circle")
            usageSection
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
