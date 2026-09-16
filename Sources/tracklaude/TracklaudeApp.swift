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
                // "remaining" mode arrives with the popover toggle (06). `model.now` advances
                // on every poll tick, so the label re-renders at least every 30 s.
                Text(MenuBarText.render(window: model.snapshot?.fiveHour, remaining: false, now: model.now))
            }
        }
        .menuBarExtraStyle(.window)
    }
}
