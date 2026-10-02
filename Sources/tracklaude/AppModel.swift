import AppKit
import Observation
import TracklaudeCore

@Observable
@MainActor
final class AppModel {
    /// The one state machine (spec › Architecture). Views render it; `AppState.applying`
    /// and the sign-in flow are the only things that move it.
    private(set) var state: AppState = .signedOut
    /// Why the last sign-in attempt failed; shown on the signed-out banner, cleared on the next attempt.
    private(set) var signInFailure: String?
    /// Why the last Sign out could not remove the Credential from the Keychain; shown on the
    /// signed-out banner, cleared on the next sign-in or Sign out.
    private(set) var signOutFailure: String?
    /// When the last fetch was issued (not when it landed): the cadence and the Refresh
    /// cooldown both count from here, so an in-flight fetch is never doubled.
    private(set) var lastFetch: Date?
    /// Drives the Refresh button's 5 s cooldown; automatic fetches do not touch it.
    private(set) var lastManualRefresh: Date?
    /// When the last 429 landed: the scheduler slows the timer for a while after it
    /// (ticket 13). Kept across Sign out — the rate budget is the account's, not the session's.
    private var lastRateLimit: Date?
    /// The clock the menu bar renders with. Advanced on every fetch and at least every 30 s
    /// through a long backoff, so Time-to-Reset never lags the wall clock by more than one
    /// interval. The popover ticks its own clock once a second while open.
    private(set) var now = Date()
    /// Used ↔ remaining (spec › Popover). Flips every percentage, menu bar included, and
    /// survives a relaunch. Not a secret, so UserDefaults is its home.
    var showsRemaining: Bool {
        didSet { defaults.set(showsRemaining, forKey: Self.showsRemainingKey) }
    }
    /// Alerts on ↔ off (spec › Alerts). Off means no permission request and no delivery;
    /// on asks macOS for permission, which it only prompts for once.
    var alertsEnabled: Bool {
        didSet {
            defaults.set(alertsEnabled, forKey: Self.alertsEnabledKey)
            requestAlertPermissionIfEnabled()
        }
    }
    /// What macOS answered; the popover says so and links to System Settings when it is
    /// anything but granted.
    private(set) var alertPermission: AlertPermission = .undetermined
    /// What macOS reports for the login item (spec › user story 32). The system is the
    /// truth: re-read on every popover open. UserDefaults `launchAtLogin` mirrors whether
    /// it reads as on — the second of the spec's two toggle booleans, never read back.
    private(set) var launchAtLoginStatus: LaunchAtLoginStatus = .notRegistered
    /// Why the last register / unregister threw; cleared on the next attempt or re-read.
    private(set) var launchAtLoginFailure: String?
    /// What has fired this cycle, per Window. Tracked even while Alerts are off, so
    /// switching them on mid-cycle cannot replay crossings the user already lived through.
    private var alertState = AlertState()
    /// The permission prompt in flight, if any; a delivery waits for its answer.
    private var permissionRequest: Task<Void, Never>?
    /// The last delivery; the next one queues behind it so Alerts reach macOS in order.
    private var delivery: Task<Void, Never>?

    /// Holds the Credential and access token (memory only, ADR-0001) and does the
    /// 401 → refresh → retry dance. `nil` exactly while not signed in.
    private var session: UsageSession?
    private var signInTask: Task<Void, Never>?
    /// The Keychain delete of the last Sign out; the next sign-in waits for it so the
    /// delete can never land on the Credential the sign-in just saved.
    private var signOutTask: Task<Void, Never>?
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
    private let notifier: AlertNotifier
    private let loginItem: LoginItem
    private let defaults: UserDefaults
    private static let showsRemainingKey = "showsRemaining"
    private static let alertsEnabledKey = "alertsEnabled"
    private static let launchAtLoginKey = "launchAtLogin"

    init(
        store: any CredentialStore = KeychainCredentialStore(),
        transport: any UsageTransport = URLSessionTransport(),
        notifier: AlertNotifier = AlertNotifier(),
        loginItem: LoginItem = LoginItem(),
        defaults: UserDefaults = .standard
    ) {
        self.store = store
        self.transport = transport
        self.notifier = notifier
        self.loginItem = loginItem
        self.defaults = defaults
        self.showsRemaining = defaults.bool(forKey: Self.showsRemainingKey)
        self.alertsEnabled = defaults.bool(forKey: Self.alertsEnabledKey)
        observeSleepAndWake()
        Task { await restoreCredential() }
        requestAlertPermissionIfEnabled()
        refreshLaunchAtLogin()
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
            lastManualRefresh: lastManualRefresh, lastRateLimit: lastRateLimit, trigger: trigger
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
            // through a backoff of up to 5 min.
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
        Self.pollLog.notice("Usage fetch issued (\(String(describing: trigger)))")
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
            Self.pollLog.error("Usage fetch failed: \(String(describing: failure))")
            if case .rateLimited = failure { lastRateLimit = Date() }
        }
        if case .snapshot(let fresh) = result {
            let decision = AlertDecision.decide(previous: alertState, snapshot: fresh)
            alertState = decision.state
            deliver(decision.alerts)
        }
        transition(to: state.applying(result, now: Date()))
    }

    // MARK: - Alerts

    /// Off means macOS is never asked (spec › Alerts). macOS prompts once and remembers.
    private func requestAlertPermissionIfEnabled() {
        guard alertsEnabled else { return }
        permissionRequest = Task { record(permission: await notifier.requestPermission()) }
    }

    /// Re-reads the answer without prompting. The popover calls this on open, so a user
    /// who just fixed it in System Settings sees the denied line go away.
    func refreshAlertPermission() {
        guard alertsEnabled else { return }
        Task { record(permission: await notifier.permission()) }
    }

    private func record(permission: AlertPermission) {
        if permission != alertPermission {
            Self.alertLog.notice("Notification permission: \(String(describing: permission))")
        }
        alertPermission = permission
    }

    /// Hands a Snapshot's Alerts to the notification center. Nothing leaves while the
    /// toggle is off or macOS has not granted permission; the state was updated regardless.
    private func deliver(_ alerts: [Alert]) {
        guard alertsEnabled, !alerts.isEmpty else { return }
        for alert in alerts {
            Self.alertLog.notice("Alert: \(alert.title)")
        }
        delivery = Task { [previous = delivery, permissionRequest] in
            await previous?.value
            // Why: ask macOS now rather than trust the cached answer — a grant made in
            // System Settings while the popover was closed, or a prompt still open when
            // this fetch landed, would otherwise cost the user this cycle's Alerts.
            await permissionRequest?.value
            // A Sign out while this was queued cancels it: those Alerts were another session's.
            guard !Task.isCancelled else { return }
            record(permission: await notifier.permission())
            guard alertsEnabled, alertPermission == .granted else {
                Self.alertLog.notice("Not delivered: permission \(String(describing: self.alertPermission))")
                return
            }
            for alert in alerts { await notifier.deliver(alert) }
        }
    }

    // MARK: - Launch at Login

    /// The toggle. Registers or unregisters with macOS, then shows whatever macOS says —
    /// which may be "requires approval" rather than on.
    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginFailure = nil
        do {
            try loginItem.setEnabled(enabled)
        } catch {
            Self.loginItemLog.error("Launch at Login change failed: \(error.localizedDescription)")
            launchAtLoginFailure = error.localizedDescription
        }
        refreshLaunchAtLogin()
    }

    /// Re-reads the login item's status. The popover calls this on open, so a change made in
    /// System Settings › Login Items is reflected without a relaunch.
    func refreshLaunchAtLogin() {
        let status = loginItem.status
        if status != launchAtLoginStatus {
            Self.loginItemLog.notice("Launch at Login: \(String(describing: status))")
        }
        launchAtLoginStatus = status
        defaults.set(status.isOn, forKey: Self.launchAtLoginKey)
    }

    /// The note's button when the login item awaits approval: System Settings › Login Items.
    func openLoginItemsSettings() {
        loginItem.openSystemSettings()
    }

    /// Logs a line only when the case or reason changes, not on every 30 s Snapshot.
    private func transition(to next: AppState) {
        let before = Self.describe(state)
        let after = Self.describe(next)
        state = next
        if before != after {
            Self.pollLog.notice("State: \(before) → \(after)")
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
            Self.log.error("Could not read the saved sign-in: \(error.localizedDescription)")
            signInFailure = "the saved sign-in could not be read (\(error.localizedDescription))"
        }
    }

    private static let log = AppLog(category: "auth")
    private static let pollLog = AppLog(category: "poll")
    private static let alertLog = AppLog(category: "alerts")
    private static let loginItemLog = AppLog(category: "login-item")

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
        signOutFailure = nil
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
                await signOutTask?.value
                let tokens = try await flow.run()
                session = UsageSession(
                    credential: Credential(refreshToken: tokens.refreshToken),
                    accessToken: tokens.accessToken, store: store, transport: transport
                )
                // Why: a new sign-in may be a different account; its Windows are not a
                // continuation of the old ones, so they get the quiet first sighting again.
                alertState = AlertState()
                transition(to: .polling(resumeState.lastSnapshot))
                poll(.timer)
            } catch {
                // Why: a cancelled URLSession request surfaces as URLError.cancelled, not
                // CancellationError, so the task flag is the reliable signal for "user cancelled".
                if Task.isCancelled || error is CancellationError {
                    transition(to: resumeState)
                } else {
                    Self.log.error("Sign-in failed: \(error.localizedDescription)")
                    signInFailure = error.localizedDescription
                    transition(to: .signedOut)
                }
            }
        }
    }

    func cancelSignIn() {
        signInTask?.cancel()
    }

    /// Sign out (spec › user story 25): the app is signed out at once — no session, no
    /// polling, no Alert history — and the Credential leaves the Keychain right after.
    func signOut() {
        guard state.isSignedIn else { return }
        cancelTimer()
        let inFlight = fetchTask
        inFlight?.cancel()
        fetchTask = nil
        fetchGeneration += 1
        session = nil
        // Why: the next sign-in may be another account; its Windows get the quiet first
        // sighting rather than a Reset Alert against this account's cycle.
        alertState = AlertState()
        delivery?.cancel()
        signInFailure = nil
        signOutFailure = nil
        transition(to: .signedOut)
        signOutTask = Task {
            // Why: a fetch cancelled mid-refresh could still write a rotated Credential
            // back; let it unwind before deleting, or the item would reappear.
            await inFlight?.value
            do {
                try await store.delete()
                Self.log.notice("Signed out: Credential removed")
            } catch {
                Self.log.error("Sign out could not remove the Credential: \(error.localizedDescription)")
                signOutFailure = error.localizedDescription
            }
        }
    }
}
