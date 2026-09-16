import SwiftUI
import TracklaudeCore

@main
struct TracklaudeApp: App {
    var body: some Scene {
        MenuBarExtra {
            PopoverView()
        } label: {
            // Why: a `Label` here collapses to icon-only in the menu bar, hiding the text.
            // An explicit HStack renders both the glyph and the readout.
            HStack(spacing: 4) {
                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                // Walking skeleton: no Snapshot yet, so the readout is always the "no Window" dash.
                Text(MenuBarText.render(fiveHour: nil))
            }
        }
        .menuBarExtraStyle(.window)
    }
}
