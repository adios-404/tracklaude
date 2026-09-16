import AppKit
import Observation
import TracklaudeCore

/// Where the app stands with Anthropic. Grows into the spec's full state machine in later tickets.
enum AuthState: Equatable {
    case signedOut
    case signingIn
    case signedIn
    case failed(String)
}

@Observable
@MainActor
final class AppModel {
    private(set) var auth: AuthState = .signedOut

    /// Memory only — never persisted (ADR-0001).
    private var accessToken: String?
    private var signInTask: Task<Void, Never>?

    private let store: any CredentialStore
    private let transport: any UsageTransport

    init(
        store: any CredentialStore = KeychainCredentialStore(),
        transport: any UsageTransport = URLSessionTransport()
    ) {
        self.store = store
        self.transport = transport
        Task { await restoreCredential() }
    }

    /// On launch: a stored Credential means the user is signed in without asking again.
    private func restoreCredential() async {
        do {
            if try await store.load() != nil {
                auth = .signedIn
            }
        } catch {
            auth = .failed(error.localizedDescription)
        }
    }

    func signIn() {
        guard signInTask == nil else { return }
        auth = .signingIn
        let flow = SignIn(
            listener: LoopbackCallbackServer(),
            openURL: { url in
                await MainActor.run { _ = NSWorkspace.shared.open(url) }
            },
            transport: transport,
            store: store
        )
        signInTask = Task {
            defer { signInTask = nil }
            do {
                let tokens = try await flow.run()
                accessToken = tokens.accessToken
                auth = .signedIn
            } catch is CancellationError {
                auth = .signedOut
            } catch {
                auth = .failed(error.localizedDescription)
            }
        }
    }

    func cancelSignIn() {
        signInTask?.cancel()
    }
}
