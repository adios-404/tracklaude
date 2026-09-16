import SwiftUI

/// The popover shown on click: sign-in status and Quit.
struct PopoverView: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            authSection
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(12)
        .frame(minWidth: 220)
    }

    @ViewBuilder
    private var authSection: some View {
        switch model.auth {
        case .signedOut:
            Button("Sign in with Claude") { model.signIn() }
        case .signingIn:
            Text("Finish signing in in your browser…")
                .foregroundStyle(.secondary)
            Button("Cancel") { model.cancelSignIn() }
        case .signedIn:
            Label("Signed in", systemImage: "checkmark.circle")
        case .failed(let reason):
            Label("Sign-in failed", systemImage: "exclamationmark.triangle")
            Text(reason)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Try again") { model.signIn() }
        }
    }
}
