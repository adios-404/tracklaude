import AppKit
import Observation
import os
import TracklaudeCore

@Observable
@MainActor
final class AppModel {
    /// The one state machine (spec › Architecture). Views render it; `AppState.applying`
    /// and the sign-in flow are the only things that move it.
    private(set) var state: AppState = .signedOut
    /// Why the last sign-in attempt failed; shown on the signed-out banner, cleared on the next attempt.
    private(set) var signInFailure: String?
    /// When the last fetch was issued (not when it landed): the cadence and the Refresh
    /// cooldown both count from here, so an in-flight fetch is never doubled.
    private(set) var lastFetch: Date?
    /// Drives the Refresh button's 5 s cooldown; automatic fetches do not touch it.
    private(set) var lastManualRefresh: Date?
    /// The clock the menu bar renders with. Advanced on every fetch and at least every 30 s
    /// through a long backoff, so Time-to-Reset never lags the wall clock by more than one
    /// interval. The popover ticks its own clock once a second while open.
    private(set) var now = Date()
    /// Used ↔ remaining (spec › Popover). Flips every percentage, menu bar included, and
    /// survives a relaunch. Not a secret, so UserDefaults is its home.
    var showsRemaining: Bool {
        didSet { defaults.set(showsRemaining, forKey: Self.showsRemainingKey) }
    }

    /// Holds the Credential and access token (memory only, ADR-0001) and does the
    /// 401 → refresh → retry dance. `nil` exactly while not signed in.
    private var session: UsageSession?
    private var signInTask: Task<Void, Never>?
    private var isAsleep = false
    /// Sleeps until the next cadence slot, then issues a fetch. Cancelled on every re-plan.
    private var timerTask: Task<Void, Never>?
    /// The one fetch in flight. Kept apart from `timerTask` so re-planning never cancels a
    /// request mid-flight (URLSession would report it as a failure).
    private var fetchTask: Task<Void, Never>?
    /// Bumped whenever an in-flight fetch is abandoned (sleep), so its completion cannot
    /// clear the handle of a fetch started afterwards (wake).
    private var fetchGeneration = 0
    private var sleepObservers: [any NSObjectProtocol] = []

    private let store: any CredentialStore
    private let transport: any UsageTransport
    private let defaults: UserDefaults
    private static let showsRemainingKey = "showsRemaining"

    init(
        store: any CredentialStore = KeychainCredentialStore(),
        transport: any UsageTransport = URLSessionTransport(),
        defaults: UserDefaults = .standard
    ) {
        self.store = store
        self.transport = transport
        self.defaults = defaults
        self.showsRemaining = defaults.bool(forKey: Self.showsRemainingKey)
        observeSleepAndWake()
        Task { await restoreCredential() }
    }

    var snapshot: Snapshot? { state.lastSnapshot }

    // MARK: - Polling

    /// What the scheduler needs to know. An expired session does not poll: every fetch
    /// would fail the same refresh, and the fix (Sign in) is on the banner.
    private var pollState: PollState {
        switch state {
        case .signedOut, .signingIn, .stale(_, .sessionExpired):
            return .signedOut
        case .backingOff(_, let until, _):
            return isAsleep ? .asleep : .backingOff(until: until)
        case .polling, .stale:
            return isAsleep ? .asleep : .active
        }
    }

    /// Whether the footer shows a Refresh button at all.
    var canRefresh: Bool { pollState != .signedOut }

    func isRefreshAllowed(now: Date) -> Bool {
        PollScheduler.isManualRefreshAllowed(state: pollState, now: now, lastManualRefresh: lastManualRefresh)
    }

    /// Re-plans the next fetch for `trigger`: right now, at a later slot, or not at all.
    /// Every entry point into polling — sign-in, wake, popover open, Refresh, a finished
    /// fetch — goes through here so the pure scheduler is the only cadence rule.
    func poll(_ trigger: PollTrigger) {
        cancelTimer()
        let now = Date()
        guard let next = PollScheduler.nextFetch(
            state: pollState, now: now, lastFetch: lastFetch,
            lastManualRefresh: lastManualRefresh, trigger: trigger
        ) else { return }
        let delay = next.timeIntervalSince(now)
        guard delay > 0 else {
            startFetch(trigger)
            return
        }
        timerTask = Task { [weak self] in
            // Why: the default tolerance lets the system coalesce timers and measured ~4 %
            // late (≈ 31 s cadence). The only error `sleep` throws is cancellation, handled
            // by the guard below. Sleeping in ≤ 30 s chunks keeps the menu-bar clock moving
            // through a backoff of up to 10 min.
            var remaining = delay
            while remaining > 0 {
                let chunk = min(remaining, PollScheduler.interval)
                try? await Task.sleep(for: .seconds(chunk), tolerance: Self.timerTolerance)
                guard !Task.isCancelled, let self else { return }
                remaining -= chunk
                if remaining > 0 { self.now = Date() }
            }
            self?.startFetch(.timer)
        }
    }

    private static let timerTolerance: Duration = .milliseconds(100)

    private func cancelTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    /// The Refresh button and the banner's Retry. The scheduler applies the cooldown and
    /// the backoff; the view disables the button.
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
        if trigger == .manualRefresh { lastManualRefresh = issuedAt }
        fetchGeneration += 1
        let generation = fetchGeneration
        Self.pollLog.notice("Usage fetch issued (\(String(describing: trigger), privacy: .public))")
        fetchTask = Task {
            await fetchUsage(issuedAt: issuedAt)
            guard generation == fetchGeneration else { return }
            fetchTask = nil
            poll(.timer)
        }
    }

    /// `issuedAt` is the same instant as `lastFetch`, so the footer's "Updated" age and the
    /// Refresh cooldown never disagree by a request's duration.
    private func fetchUsage(issuedAt: Date) async {
        guard let session else {
            // Unreachable while `pollState` requires a signed-in state; loud if that ever changes.
            Self.log.fault("Usage fetch attempted without a session")
            return
        }
        let result = await session.fetch(now: issuedAt)
        // A fetch abandoned at sleep is not a failure the user needs to see.
        guard !Task.isCancelled else { return }
        // Why: the fetch may outlive the state that issued it (a sign-in started meanwhile);
        // its result must not drag the app back into a signed-in state.
        guard state.isSignedIn else { return }
        if case .failed(let failure) = result {
            Self.pollLog.error("Usage fetch failed: \(String(describing: failure), privacy: .public)")
        }
        transition(to: state.applying(result, now: Date()))
    }

    /// Logs a line only when the case or reason changes, not on every 30 s Snapshot.
    private func transition(to next: AppState) {
        let before = Self.describe(state)
        let after = Self.describe(next)
        state = next
        if before != after {
            Self.pollLog.notice("State: \(before, privacy: .public) → \(after, privacy: .public)")
        }
    }

    /// Case and reason only — never a Snapshot's numbers, never a token.
    private static func describe(_ state: AppState) -> String {
        switch state {
        case .signedOut: return "signedOut"
        case .signingIn: return "signingIn"
        case .polling: return "polling"
        case .stale(_, let reason): return "stale(\(reason))"
        case .backingOff(_, let until, let count):
            return "backingOff(until \(until.formatted(date: .omitted, time: .standard)), 429 #\(count))"
        }
    }

    /// `NSWorkspace` posts these on the main queue; the model is main-actor bound, so the
    /// hop is a no-op the compiler cannot see. Observers live as long as the model (the
    /// app's lifetime) and are never removed.
    private func observeSleepAndWake() {
        let center = NSWorkspace.shared.notificationCenter
        sleepObservers = [
            center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.machineWillSleep() }
            },
            center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.machineDidWake() }
            },
        ]
    }

    private func machineWillSleep() {
        isAsleep = true
        cancelTimer()
        // Why: a request caught mid-flight by sleep is stale on wake and, left running,
        // would make the wake fetch a no-op until it timed out (up to 30 s). Drop it.
        fetchTask?.cancel()
        fetchTask = nil
        fetchGeneration += 1
        Self.pollLog.notice("Sleeping: polling suspended")
    }

    private func machineDidWake() {
        isAsleep = false
        Self.pollLog.notice("Woke: polling resumes")
        poll(.wake)
    }

    // MARK: - Session

    /// On launch: a stored Credential means the user is signed in without asking again.
    /// Only the Credential survives a relaunch; the session refreshes before its first fetch.
    private func restoreCredential() async {
        do {
            guard let credential = try await store.load() else { return }
            session = UsageSession(credential: credential, store: store, transport: transport)
            transition(to: .polling(nil))
            poll(.timer)
        } catch {
            // Status text only — never the Credential. The banner reads
            // "Sign-in failed: the saved sign-in could not be read (…)".
            Self.log.error("Could not read the saved sign-in: \(error.localizedDescription, privacy: .public)")
            signInFailure = "the saved sign-in could not be read (\(error.localizedDescription))"
        }
    }

    private static let subsystem = Bundle.main.bundleIdentifier ?? "tracklaude"
    private static let log = Logger(subsystem: subsystem, category: "auth")
    private static let pollLog = Logger(subsystem: subsystem, category: "poll")

    /// The banner's one button.
    func perform(_ action: PopoverBanner.Action) {
        switch action {
        case .signIn: signIn()
        case .retry: refresh()
        case .cancelSignIn: cancelSignIn()
        }
    }

    func signIn() {
        guard signInTask == nil else { return }
        // Why: the state a cancelled sign-in returns to. From an expired session that is the
        // expired session, readout and all — not a blank signed-out.
        let resumeState = state
        signInFailure = nil
        transition(to: .signingIn)
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
                session = UsageSession(
                    credential: Credential(refreshToken: tokens.refreshToken),
                    accessToken: tokens.accessToken, store: store, transport: transport
                )
                transition(to: .polling(resumeState.lastSnapshot))
                poll(.timer)
            } catch {
                // Why: a cancelled URLSession request surfaces as URLError.cancelled, not
                // CancellationError, so the task flag is the reliable signal for "user cancelled".
                if Task.isCancelled || error is CancellationError {
                    transition(to: resumeState)
                } else {
                    Self.log.error("Sign-in failed: \(error.localizedDescription, privacy: .public)")
                    signInFailure = error.localizedDescription
                    transition(to: .signedOut)
                }
            }
        }
    }

    func cancelSignIn() {
        signInTask?.cancel()
    }
}
