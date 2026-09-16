import SwiftUI
import TracklaudeCore

/// The popover shown on click: the banner (when something is wrong), a bare usage
/// readout, and the footer.
struct PopoverView: View {
    let model: AppModel

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
                Divider()
                footer(now: context.date)
            }
        }
        .padding(12)
        .frame(minWidth: 260)
        // MenuBarExtra rebuilds the content view on each open, so this fires per open.
        .onAppear { model.poll(.popoverOpened) }
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

    /// A bare readout of the last Snapshot — kept, dimmed, while Stale; the full row layout
    /// is ticket 06.
    @ViewBuilder
    private func usageSection(now: Date) -> some View {
        if let snapshot = model.snapshot {
            Group {
                windowLine("5-hour", snapshot.fiveHour, now: now)
                windowLine("7-day", snapshot.sevenDay, now: now)
                ForEach(snapshot.perModel, id: \.model) { entry in
                    windowLine(entry.model, entry.window, now: now)
                }
            }
            .foregroundStyle(model.state.staleReason == nil ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
        } else if case .polling = model.state {
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
}
