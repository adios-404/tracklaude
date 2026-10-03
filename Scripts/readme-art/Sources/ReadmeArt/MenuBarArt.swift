import SwiftUI
import TracklaudeCore

/// The menu-bar item as TracklaudeApp's `MenuBarExtra` label builds it, at the menu bar's
/// 13 pt. Keep the two in step: this copy exists because the label lives inside the App.
struct MenuItemArt: View {
    let label: MenuBarLabel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
            Text(label.text)
        }
        .font(.system(size: 13))
        .foregroundStyle(label.isDimmed ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
        .fixedSize()
    }
}

/// One of the system's menu-bar glyphs (Wi-Fi, battery…) for the scene around the item.
struct GlyphArt: View {
    let name: String

    var body: some View {
        Image(systemName: name)
            .font(.system(size: 14))
            .foregroundStyle(.primary)
            .fixedSize()
    }
}
