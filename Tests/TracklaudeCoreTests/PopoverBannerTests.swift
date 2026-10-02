import Foundation
import Testing
import TracklaudeCore

// Spec › Popover: a banner with the plain-English reason and a single action button.
private let now = Date(timeIntervalSince1970: 1_800_000_000)
private let snapshot = Snapshot(fiveHour: Window(utilization: 42, resetsAt: now), sevenDay: nil, fetchedAt: now)

@Test("a healthy poll shows no banner")
func pollingHasNoBanner() {
    #expect(PopoverBanner.render(state: .polling(snapshot), now: now) == nil)
    #expect(PopoverBanner.render(state: .polling(nil), now: now) == nil)
}

@Test("signed out explains and offers Sign in")
func signedOut() {
    #expect(PopoverBanner.render(state: .signedOut, now: now) == PopoverBanner(message: "Not signed in.", action: .signIn))
}

@Test("a failed sign-in keeps the reason on the banner, still offering Sign in")
func signedOutAfterFailure() {
    let banner = PopoverBanner.render(state: .signedOut, signInFailure: "Anthropic refused the sign-in code (HTTP 400).", now: now)
    #expect(banner == PopoverBanner(message: "Sign-in failed: Anthropic refused the sign-in code (HTTP 400).", action: .signIn))
}

@Test("a Sign out whose Keychain delete failed says so — the user is signed out, but the item is still there")
func signedOutAfterFailedDelete() {
    let banner = PopoverBanner.render(state: .signedOut, signOutFailure: "Keychain: The user name or passphrase you entered is not correct.", now: now)
    #expect(banner == PopoverBanner(
        message: "Signed out, but the saved sign-in could not be removed from the Keychain: Keychain: The user name or passphrase you entered is not correct.",
        action: .signIn
    ))
}

@Test("signing in points at the browser and offers Cancel")
func signingIn() {
    #expect(PopoverBanner.render(state: .signingIn, now: now) == PopoverBanner(message: "Finish signing in in your browser…", action: .cancelSignIn))
}

@Test("offline explains and offers Retry")
func offline() {
    #expect(PopoverBanner.render(state: .stale(snapshot, .offline), now: now)
        == PopoverBanner(message: "Can't reach Anthropic. Check your connection.", action: .retry))
}

@Test("a server error explains and offers Retry")
func serverError() {
    #expect(PopoverBanner.render(state: .stale(nil, .serverError), now: now)
        == PopoverBanner(message: "Anthropic's usage service isn't answering properly.", action: .retry))
}

@Test("an expired session explains and offers Sign in — Retry would only fail again")
func sessionExpired() {
    #expect(PopoverBanner.render(state: .stale(snapshot, .sessionExpired), now: now)
        == PopoverBanner(message: "Your session expired. Sign in again.", action: .signIn))
}

// Ticket 16: no banner while the reading is younger than 10 min.
private let oldSnapshot = Snapshot(fiveHour: Window(utilization: 42, resetsAt: now), sevenDay: nil, fetchedAt: now.addingTimeInterval(-600))

@Test("a refusal on a reading younger than 10 min shows no banner")
func bannerQuietWhileFresh() {
    let state = AppState.backingOff(snapshot, until: now.addingTimeInterval(60), consecutiveRateLimits: 1)
    #expect(PopoverBanner.render(state: state, now: now) == nil)
    #expect(PopoverBanner.render(state: state, now: now.addingTimeInterval(599)) == nil)
}

@Test("backing off on an old reading shows the countdown and no button: nothing the user does can end a lockout sooner")
func backingOffCountsDown() {
    let state = AppState.backingOff(oldSnapshot, until: now.addingTimeInterval(299), consecutiveRateLimits: 1)
    #expect(PopoverBanner.render(state: state, now: now)
        == PopoverBanner(message: "Anthropic is rate-limiting usage checks. Retrying in 4 min 59 s.", action: nil))
    #expect(PopoverBanner.render(state: state, now: now.addingTimeInterval(240))?.message
        == "Anthropic is rate-limiting usage checks. Retrying in 59 s.")
}

@Test("once the lockout has passed the banner says the retry is under way")
func backingOffElapsed() {
    let state = AppState.backingOff(oldSnapshot, until: now, consecutiveRateLimits: 1)
    #expect(PopoverBanner.render(state: state, now: now)?.message == "Anthropic is rate-limiting usage checks. Retrying now…")
}

@Test("each action has the button title the spec names")
func actionTitles() {
    #expect(PopoverBanner.Action.signIn.title == "Sign in")
    #expect(PopoverBanner.Action.retry.title == "Retry")
    #expect(PopoverBanner.Action.cancelSignIn.title == "Cancel")
}
