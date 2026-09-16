# 04: 30-second polling

**What to build:** The menu-bar value stays current on its own: a fetch every 30 seconds flat while signed in, none while the Mac sleeps, an immediate fetch on wake, on popover open, and on a Refresh button in the popover (5-second cooldown so a double-click doesn't double-fetch). The popover footer reads "Updated 12 s ago" and ticks.

**Blocked by:** 03 Live 5-hour readout

**Status:** ready-for-agent

- [ ] Poll scheduler is a pure function of (state, now, last fetch, trigger) returning the next fetch time; tests cover steady state, wake, popover-open, manual with and without cooldown
- [ ] Sleep suspends the timer; wake triggers a fetch and resumes the 30 s cadence
- [ ] Opening the popover triggers a fetch; the footer's "Updated N s ago" updates every second while the popover is open
- [ ] Refresh button fetches immediately and is disabled for 5 s afterwards
- [ ] No fetch is ever issued while signed out
- [ ] Running the app for 10 minutes shows fetches at 30 s intervals (observed via the log, credential redacted)

## Comments

**2026-09-16 — handoff from ticket 03.** `UsageFetch.perform(accessToken:transport:now:)` does
one classified fetch; `AppModel.fetchUsage()` calls it once after restore/sign-in. The endpoint
reflects new usage at ≤ 10 s, so 30 s stands. Rate limit is per access token, roughly 50
requests per rolling 10 minutes, `Retry-After: 300` on a 429 — your 10-minute run should see no
429 at 30 s; if it does, the budget is smaller than measured. The menu-bar label currently
renders with `Date()` at SwiftUI render time and only re-renders when the Snapshot changes, so
Time-to-Reset goes stale between polls until your timer drives `now`.
