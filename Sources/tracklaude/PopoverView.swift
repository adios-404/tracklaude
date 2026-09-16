import SwiftUI

/// The popover shown on click. Walking skeleton: Quit only.
struct PopoverView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("tracklaude")
                .font(.headline)
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(12)
        .frame(minWidth: 200)
    }
}
