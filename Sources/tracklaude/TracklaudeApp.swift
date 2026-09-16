import SwiftUI
import TracklaudeCore

@main
struct TracklaudeApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(model: model)
        } label: {
            // Why: a `Label` here collapses to icon-only in the menu bar, hiding the text.
            // An explicit HStack renders both the glyph and the readout.
            HStack(spacing: 4) {
                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                // "remaining" mode and a ticking `now` arrive with the popover toggle (06)
                // and the poll timer (04); until then the label re-renders per Snapshot.
                Text(MenuBarText.render(fiveHour: model.snapshot?.fiveHour, remaining: false, now: Date()))
            }
        }
        .menuBarExtraStyle(.window)
    }
}
