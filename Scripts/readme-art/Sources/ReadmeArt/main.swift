import AppKit
import SwiftUI
import TracklaudeCore

// Draws the app's real views with a sample reading, as transparent PNGs at 4x, in light
// and dark: the popover, the menu-bar item in each of its states, and the system glyphs the
// README scene puts beside it. Also writes meta.json with the scene's clock text.
// Usage: ReadmeArt <out dir>   (render.sh runs it with a blue accent and the en_US locale)

/// Renders `view` through AppKit rather than `ImageRenderer`, which draws AppKit-backed
/// controls (the segmented picker, checkboxes, buttons) as placeholders.
@MainActor
func png<V: View>(_ view: V, appearance: NSAppearance.Name, to path: String) {
    // 4x: the README shows the menu-bar chips at 1.25x on a 3x render, so 3x art would be
    // stretched; 4x never is.
    let scale: CGFloat = 4
    let host = NSHostingView(rootView: view)
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
        styleMask: [.borderless], backing: .buffered, defer: false
    )
    window.appearance = NSAppearance(named: appearance)
    window.isOpaque = false
    window.backgroundColor = .clear
    window.contentView = host
    // Why the run-loop turns: SwiftUI lays out and resolves its TimelineView on the next
    // pass, and fittingSize is only right after it.
    RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    let size = host.fittingSize
    window.setContentSize(size)
    host.frame = NSRect(origin: .zero, size: size)
    host.layoutSubtreeIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.3))

    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = size
    host.cacheDisplay(in: host.bounds, to: rep)
    let srgb = rep.converting(to: .sRGB, renderingIntent: .default) ?? rep
    guard let data = srgb.representation(using: .png, properties: [:]) else { fatalError("no PNG for \(path)") }
    do { try data.write(to: URL(fileURLWithPath: path)) } catch { fatalError("\(path): \(error)") }
}

/// The sample reading every picture shows. Anchored to the moment it is drawn: the
/// popover's TimelineView reads the real clock, so "resets in 2h14m" and "Updated 4 s ago"
/// only come out exact when the Snapshot is built right before each render.
func sampleSnapshot(at instant: Date = Date()) -> Snapshot {
    let weekly = instant.addingTimeInterval(3 * 86400 + 4 * 3600 + 30)
    return Snapshot(
        fiveHour: Window(utilization: 42, resetsAt: instant.addingTimeInterval(2 * 3600 + 14 * 60 + 40)),
        sevenDay: Window(utilization: 63, resetsAt: weekly),
        perModel: [ModelWindow(model: "Fable", window: Window(utilization: 18, resetsAt: weekly))],
        fetchedAt: instant.addingTimeInterval(-4)
    )
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let now = Date()

MainActor.assumeIsolated {
    for (theme, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
        // `.key`: the real popover is the key window while open, so its checkboxes and
        // picker draw in their active colours. An off-screen window never becomes key.
        let popover = PopoverView(model: AppModel(state: .polling(sampleSnapshot())))
            .environment(\.controlActiveState, .key)
        png(popover, appearance: appearance, to: "\(out)/popover-\(theme).png")

        let reading = sampleSnapshot(at: now)
        let states: [(String, AppState)] = [
            ("live", .polling(reading)),
            ("stale", .stale(reading, .offline)),
            ("nowindow", .polling(Snapshot(fiveHour: nil, sevenDay: reading.sevenDay, fetchedAt: now))),
            ("signedout", .signedOut),
        ]
        for (name, state) in states {
            let label = MenuBarText.render(state: state, remaining: false, now: now)
            png(MenuItemArt(label: label), appearance: appearance, to: "\(out)/item-\(name)-\(theme).png")
        }
        for glyph in ["wifi", "battery.75percent", "magnifyingglass", "switch.2"] {
            png(GlyphArt(name: glyph), appearance: appearance, to: "\(out)/glyph-\(glyph)-\(theme).png")
        }
    }

    // The scene's clock agrees with the popover's absolute reset times: same instant,
    // same locale and time zone.
    let clock = DateFormatter()
    clock.locale = Locale(identifier: "en_US")
    clock.timeZone = .current
    clock.dateFormat = "EEE MMM d  h:mm a"
    let meta = ["clock": clock.string(from: now)]
    do {
        let json = try JSONSerialization.data(withJSONObject: meta, options: [.prettyPrinted, .sortedKeys])
        try json.write(to: URL(fileURLWithPath: "\(out)/meta.json"))
    } catch {
        fatalError("meta.json: \(error)")
    }
}
