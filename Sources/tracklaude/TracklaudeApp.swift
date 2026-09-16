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
                // No Snapshot yet (ticket 03), so the readout is always the "no Window" dash.
                Text(MenuBarText.render(fiveHour: nil, remaining: false, now: Date()))
            }
        }
        .menuBarExtraStyle(.window)
    }
}
