import Foundation
import Testing
import TracklaudeCore

// The state machine: (previous state, fetch result, now) → next state. Spec › Architecture.
private let now = Date(timeIntervalSince1970: 1_800_000_000)
private let snapshot = Snapshot(
    fiveHour: Window(utilization: 48, resetsAt: now.addingTimeInterval(3600)), sevenDay: nil, fetchedAt: now
)
private let older = Snapshot(
    fiveHour: Window(utilization: 12, resetsAt: now.addingTimeInterval(7200)), sevenDay: nil, fetchedAt: now.addingTimeInterval(-30)
)

@Test("a Snapshot puts the app in polling with that Snapshot, from any signed-in state")
func snapshotEntersPolling() {
    let states: [AppState] = [
        .polling(nil), .polling(older), .stale(older, .offline), .stale(nil, .serverError),
        .backingOff(older, until: now.addingTimeInterval(300), consecutiveRateLimits: 3),
    ]
    for state in states {
        #expect(state.applying(.snapshot(snapshot), now: now) == .polling(snapshot))
    }
}

@Test("a network failure keeps the last Snapshot, marked stale for being offline")
func offlineKeepsLastSnapshot() {
    #expect(AppState.polling(older).applying(.failed(.offline), now: now) == .stale(older, .offline))
    #expect(AppState.polling(nil).applying(.failed(.offline), now: now) == .stale(nil, .offline))
}

@Test("a server error keeps the last Snapshot, marked stale for a server error")
func serverErrorKeepsLastSnapshot() {
    #expect(AppState.polling(older).applying(.failed(.serverError), now: now) == .stale(older, .serverError))
}

@Test("a dead Credential keeps the last Snapshot, marked stale for an expired session")
func sessionExpiredKeepsLastSnapshot() {
    #expect(AppState.polling(older).applying(.failed(.sessionExpired), now: now) == .stale(older, .sessionExpired))
}

@Test("a stale reason is replaced by the newest failure, and the Snapshot carried across")
func laterFailureReplacesReason() {
    let state = AppState.stale(older, .offline).applying(.failed(.serverError), now: now)
    #expect(state == .stale(older, .serverError))
}

@Test("a 429 without Retry-After enters backing off 60 s out, then doubles on each further 429")
func rateLimitBacksOffExponentially() {
    let first = AppState.polling(older).applying(.failed(.rateLimited(retryAfter: nil)), now: now)
    #expect(first == .backingOff(older, until: now.addingTimeInterval(60), consecutiveRateLimits: 1))

    let later = now.addingTimeInterval(60)
    let second = first.applying(.failed(.rateLimited(retryAfter: nil)), now: later)
    #expect(second == .backingOff(older, until: later.addingTimeInterval(120), consecutiveRateLimits: 2))
}

@Test("a 429 with Retry-After backs off exactly that long")
func rateLimitHonoursRetryAfter() {
    let state = AppState.polling(older).applying(.failed(.rateLimited(retryAfter: 300)), now: now)
    #expect(state == .backingOff(older, until: now.addingTimeInterval(300), consecutiveRateLimits: 1))
}

@Test("any success resets the backoff: the next 429 starts again at 60 s")
func successResetsBackoff() {
    let backedOff = AppState.backingOff(older, until: now, consecutiveRateLimits: 4)
    let recovered = backedOff.applying(.snapshot(snapshot), now: now)
    let limitedAgain = recovered.applying(.failed(.rateLimited(retryAfter: nil)), now: now)
    #expect(limitedAgain == .backingOff(snapshot, until: now.addingTimeInterval(60), consecutiveRateLimits: 1))
}

@Test("a different failure between two 429s restarts the schedule: the count lives in backing off only")
func otherFailuresRestartBackoff() {
    let backedOff = AppState.backingOff(older, until: now, consecutiveRateLimits: 2)
    let offline = backedOff.applying(.failed(.offline), now: now)
    #expect(offline == .stale(older, .offline))
    let limited = offline.applying(.failed(.rateLimited(retryAfter: nil)), now: now)
    #expect(limited == .backingOff(older, until: now.addingTimeInterval(60), consecutiveRateLimits: 1))
}

@Test("every state exposes the Snapshot it is showing, if any")
func lastSnapshotAccessor() {
    #expect(AppState.signedOut.lastSnapshot == nil)
    #expect(AppState.signingIn.lastSnapshot == nil)
    #expect(AppState.polling(nil).lastSnapshot == nil)
    #expect(AppState.polling(snapshot).lastSnapshot == snapshot)
    #expect(AppState.stale(older, .offline).lastSnapshot == older)
    #expect(AppState.backingOff(older, until: now, consecutiveRateLimits: 1).lastSnapshot == older)
}

@Test("only the states that came from a sign-in count as signed in")
func isSignedInAccessor() {
    #expect(AppState.signedOut.isSignedIn == false)
    #expect(AppState.signingIn.isSignedIn == false)
    #expect(AppState.polling(nil).isSignedIn == true)
    #expect(AppState.stale(nil, .sessionExpired).isSignedIn == true)
    #expect(AppState.backingOff(nil, until: now, consecutiveRateLimits: 1).isSignedIn == true)
}

@Test("backing off reads as rate-limited only once the reading is 10 min old; healthy and signed-out states have no reason")
func staleReasonAccessor() {
    let fresh = Snapshot(fiveHour: nil, sevenDay: nil, fetchedAt: now.addingTimeInterval(-599))
    let old = Snapshot(fiveHour: nil, sevenDay: nil, fetchedAt: now.addingTimeInterval(-600))
    #expect(AppState.backingOff(fresh, until: now, consecutiveRateLimits: 1).staleReason(now: now) == nil)
    #expect(AppState.backingOff(old, until: now, consecutiveRateLimits: 1).staleReason(now: now) == .rateLimited)
    #expect(AppState.backingOff(nil, until: now, consecutiveRateLimits: 1).staleReason(now: now) == .rateLimited)
    #expect(AppState.stale(fresh, .sessionExpired).staleReason(now: now) == .sessionExpired)
    #expect(AppState.stale(fresh, .offline).staleReason(now: now) == .offline)
    #expect(AppState.polling(snapshot).staleReason(now: now) == nil)
    #expect(AppState.signedOut.staleReason(now: now) == nil)
}
