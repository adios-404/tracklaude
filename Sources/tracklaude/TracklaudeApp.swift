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
            // "remaining" mode arrives with the popover toggle (06). `model.now` advances on
            // every poll tick, so the label re-renders at least every 30 s.
            let label = MenuBarText.render(state: model.state, remaining: false, now: model.now)
            HStack(spacing: 4) {
                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                Text(label.text)
            }
            .foregroundStyle(label.isDimmed ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
        }
        .menuBarExtraStyle(.window)
    }
}
