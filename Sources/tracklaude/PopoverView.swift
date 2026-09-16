import SwiftUI

/// The popover shown on click. Walking skeleton: Quit only.
struct PopoverView: View {
    var body: some View {
        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
        .padding(12)
        .frame(minWidth: 160)
    }
}
