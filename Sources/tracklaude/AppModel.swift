import AppKit
import Observation
import os
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
    /// The latest successful fetch; the menu bar renders its 5-hour Window.
    private(set) var snapshot: Snapshot?
    /// Plain-English reason the last fetch produced no Snapshot. Ticket 05 turns this into Stale.
    private(set) var fetchFailure: String?
    /// When the last fetch was issued (not when it landed): the cadence and the Refresh
    /// cooldown both count from here, so an in-flight fetch is never doubled.
    private(set) var lastFetch: Date?
    /// The clock the menu bar renders with. Advanced on every fetch, so Time-to-Reset lags
    /// the wall clock by at most one interval even when a fetch fails. The popover ticks
    /// its own clock once a second while open.
    private(set) var now = Date()

    /// Memory only — never persisted (ADR-0001).
    private var accessToken: String?
    private var signInTask: Task<Void, Never>?
    private var isAsleep = false
    /// Sleeps until the next cadence slot, then issues a fetch. Cancelled on every re-plan.
    private var timerTask: Task<Void, Never>?
    /// The one fetch in flight. Kept apart from `timerTask` so re-planning never cancels a
    /// request mid-flight (URLSession would report it as a failure).
    private var fetchTask: Task<Void, Never>?
    private var sleepObservers: [any NSObjectProtocol] = []

    private let store: any CredentialStore
    private let transport: any UsageTransport

    init(
        store: any CredentialStore = KeychainCredentialStore(),
        transport: any UsageTransport = URLSessionTransport()
    ) {
        self.store = store
        self.transport = transport
        observeSleepAndWake()
        Task { await restoreCredential() }
    }

    // MARK: - Polling

    private var pollState: PollState {
        guard auth == .signedIn else { return .signedOut }
        return isAsleep ? .asleep : .active
    }

    /// Re-plans the next fetch for `trigger`: right now, at a later slot, or not at all.
    /// Every entry point into polling — sign-in, wake, popover open, Refresh, a finished
    /// fetch — goes through here so the pure scheduler is the only cadence rule.
    func poll(_ trigger: PollTrigger) {
        timerTask?.cancel()
        timerTask = nil
        let now = Date()
        guard let next = PollScheduler.nextFetch(
            state: pollState, now: now, lastFetch: lastFetch, trigger: trigger
        ) else { return }
        let delay = next.timeIntervalSince(now)
        guard delay > 0 else {
            startFetch(trigger)
            return
        }
        timerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.startFetch(.timer)
        }
    }

    /// The Refresh button. The scheduler applies the cooldown; the view disables the button.
    func refresh() {
        poll(.manualRefresh)
    }

    private func startFetch(_ trigger: PollTrigger) {
        // Why: one request in flight at a time. A popover open during a fetch rides on the
        // one already running rather than spending rate budget on a duplicate.
        guard fetchTask == nil else { return }
        let issuedAt = Date()
        lastFetch = issuedAt
        now = issuedAt
        Self.pollLog.notice("Usage fetch issued (\(String(describing: trigger), privacy: .public))")
        fetchTask = Task {
            await fetchUsage()
            fetchTask = nil
            poll(.timer)
        }
    }

    /// `NSWorkspace` posts these on the main queue; the model is main-actor bound, so the
    /// hop is a no-op the compiler cannot see. Observers live as long as the model (the
    /// app's lifetime) and are never removed.
    private func observeSleepAndWake() {
        let center = NSWorkspace.shared.notificationCenter
        sleepObservers = [
            center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { [weak self] in self?.machineWillSleep() }
            },
            center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { [weak self] in self?.machineDidWake() }
            },
        ]
    }

    private func machineWillSleep() {
        isAsleep = true
        timerTask?.cancel()
        timerTask = nil
        Self.pollLog.notice("Sleeping: polling suspended")
    }

    private func machineDidWake() {
        isAsleep = false
        Self.pollLog.notice("Woke: polling resumes")
        poll(.wake)
    }

    // MARK: - Session

    /// On launch: a stored Credential means the user is signed in without asking again.
    /// Only the Credential survives a relaunch, so the first fetch starts with a refresh.
    private func restoreCredential() async {
        do {
            guard let credential = try await store.load() else { return }
            auth = .signedIn
            try await refreshAccessToken(with: credential)
            poll(.timer)
        } catch {
            // Status text only — never the Credential.
            Self.log.error("Could not restore the session: \(error.localizedDescription, privacy: .public)")
            auth = .failed(error.localizedDescription)
        }
    }

    /// Trades the Credential for an access token; a rotated Credential is stored at once,
    /// because the old one is dead the moment the server rotates it.
    private func refreshAccessToken(with credential: Credential) async throws {
        let tokens = try await OAuthRefresh.refresh(credential, transport: transport)
        accessToken = tokens.accessToken
        if tokens.refreshToken != credential.refreshToken {
            try await store.save(Credential(refreshToken: tokens.refreshToken))
        }
    }

    private func fetchUsage() async {
        guard let accessToken else { return }
        do {
            snapshot = try await UsageFetch.perform(accessToken: accessToken, transport: transport, now: Date())
            fetchFailure = nil
        } catch {
            Self.log.error("Usage fetch failed: \(error.localizedDescription, privacy: .public)")
            fetchFailure = error.localizedDescription
        }
    }

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "tracklaude", category: "auth")
    private static let pollLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "tracklaude", category: "poll")

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
                poll(.timer)
            } catch {
                // Why: a cancelled URLSession request surfaces as URLError.cancelled, not
                // CancellationError, so the task flag is the reliable signal for "user cancelled".
                auth = Task.isCancelled || error is CancellationError
                    ? .signedOut
                    : .failed(error.localizedDescription)
            }
        }
    }

    func cancelSignIn() {
        signInTask?.cancel()
    }
}
