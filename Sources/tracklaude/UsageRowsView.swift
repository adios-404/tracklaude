import SwiftUI
import TracklaudeCore

/// The popover's usage section: one row per reported Window, or the one-line message
/// when the Snapshot named none. Dimmed while Stale, like the menu bar.
struct UsageRowsView: View {
    let readout: PopoverReadout
    let isStale: Bool

    private static let staleOpacity = 0.55
    private static let rowSpacing: CGFloat = 12

    var body: some View {
        Group {
            switch readout {
            case .rows(let rows):
                VStack(alignment: .leading, spacing: Self.rowSpacing) {
                    ForEach(rows) { row in
                        UsageRowView(row: row)
                    }
                }
            case .noWindows:
                Text(PopoverReadout.noWindowsMessage)
                    .foregroundStyle(.secondary)
            }
        }
        // Why: opacity rather than a secondary foreground, so the bar colours dim with the text.
        .opacity(isStale ? Self.staleOpacity : 1)
    }
}

/// Name and percentage on one line, the bar under them, then the Reset texts.
struct UsageRowView: View {
    let row: PopoverRow

    private static let barHeight: CGFloat = 6
    private static let lineSpacing: CGFloat = 4

    var body: some View {
        VStack(alignment: .leading, spacing: Self.lineSpacing) {
            HStack {
                Text(row.name)
                    .fontWeight(.medium)
                Spacer()
                Text("\(row.percent)%")
                    .monospacedDigit()
            }
            UsageBar(fraction: Double(row.percent) / 100, tone: row.tone)
                .frame(height: Self.barHeight)
            if row.resetsIn != nil || row.resetsAt != nil {
                Text([row.resetsIn, row.resetsAt].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
}

/// A horizontal bar filled to `fraction`, coloured by the row's tone.
struct UsageBar: View {
    let fraction: Double
    let tone: PopoverRow.Tone

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                // Why: the spec says Utilization is 0–100, but a fill wider than its track
                // would overflow the row; clamping costs nothing and keeps the layout honest.
                Capsule()
                    .fill(color)
                    .frame(width: geometry.size.width * min(max(fraction, 0), 1))
            }
        }
    }

    private var color: Color {
        switch tone {
        case .normal: return .accentColor
        case .warning: return .orange
        case .critical: return .red
        }
    }
}
