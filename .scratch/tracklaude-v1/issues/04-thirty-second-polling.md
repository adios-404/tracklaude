# 04: 30-second polling

**What to build:** The menu-bar value stays current on its own: a fetch every 30 seconds flat while signed in, none while the Mac sleeps, an immediate fetch on wake, on popover open, and on a Refresh button in the popover (5-second cooldown so a double-click doesn't double-fetch). The popover footer reads "Updated 12 s ago" and ticks.

**Blocked by:** 03 Live 5-hour readout

**Status:** done (2026-09-16, commits 08fcd6d, c0ff2c8, review fixes, d455854)

- [x] Poll scheduler is a pure function of (state, now, last fetch, trigger) returning the next fetch time; tests cover steady state, wake, popover-open, manual with and without cooldown
- [x] Sleep suspends the timer; wake triggers a fetch and resumes the 30 s cadence
- [x] Opening the popover triggers a fetch; the footer's "Updated N s ago" updates every second while the popover is open
- [x] Refresh button fetches immediately and is disabled for 5 s afterwards
- [x] No fetch is ever issued while signed out
- [x] Running the app for 10 minutes shows fetches at 30 s intervals (observed via the log, credential redacted)

## Comments

**2026-09-16 — handoff from ticket 03.** `UsageFetch.perform(accessToken:transport:now:)` does
one classified fetch; `AppModel.fetchUsage()` calls it once after restore/sign-in. The endpoint
reflects new usage at ≤ 10 s, so 30 s stands. Rate limit is per access token, roughly 50
requests per rolling 10 minutes, `Retry-After: 300` on a 429 — your 10-minute run should see no
429 at 30 s; if it does, the budget is smaller than measured. The menu-bar label currently
renders with `Date()` at SwiftUI render time and only re-renders when the Snapshot changes, so
Time-to-Reset goes stale between polls until your timer drives `now`.

**2026-09-16 — implemented.** Core: `Polling/PollScheduler` (`PollState`, `PollTrigger`,
`nextFetch(state:now:lastFetch:lastManualRefresh:trigger:)`, `isManualRefreshAllowed`) and
`UpdatedAgoText`. 15 new tests; 62 total, offline. Executable: `AppModel.poll(_:)` is the single
entry point — sign-in, wake, popover open, Refresh and a finished fetch all go through the
scheduler; one `timerTask` (sleep-until-slot) and one `fetchTask` (the request), kept apart so a
re-plan never cancels a request mid-flight. Sleep/wake via `NSWorkspace` notifications. The
popover body sits in a `TimelineView(.periodic(by: 1))`, which ticks the footer and the Refresh
button while open and stops when closed; the menu-bar label renders with `model.now`, advanced on
every fetch. `MenuBarExtra(.window)` does rebuild the content view on every open, so `.onAppear`
is a reliable "popover opened" hook (log shows `popoverOpened` on every open).

**Observed run** (fixed build, pid 95031): timer fetches at 23:38:05 → 23:41:35 at 30.05–30.12 s
spacing, then continuing every 30 s through the rate-limit below. The first build showed ~31 s:
`Task.sleep`'s default tolerance lets the system coalesce timers (~4 % late, measured in
isolation); an explicit 100 ms tolerance fixed it. Refresh: fetches, greys, re-enables after 5 s
(owner-verified). Sleep/wake was not exercised — it needs a real sleep; ticket 05's Wi-Fi check
is a good moment to also close the lid once and look for `Sleeping` / `Woke` / `(wake)` in the log.

**Deviation, corrected in d455854:** the cooldown was first measured from *any* fetch, which
greyed Refresh for the first 5 s of every popover open (the open fetches too); the owner read
that as broken. It now counts from the last manual Refresh, as the spec says. The scheduler took a
fifth input (`lastManualRefresh`) for it.

**Deviations kept:** `UpdatedAgoText` also renders `min` / `h` and "Not updated yet"; ⌘R on
Refresh; `pollState` requires an access token, not just `auth == .signedIn` (during restore
`auth` flips before the refresh grant lands, and a popover open in that gap stamped a fetch that
sent nothing). Sleep cancels an in-flight request (generation-guarded) so the wake fetch is never
a no-op behind a stale one.

Findings that matter downstream:

- **The usage rate budget is per account and about half what ticket 03 measured.** 23 requests in
  the rolling 10 min before 23:42:13 — across two access tokens (a relaunch did a fresh refresh
  grant at 23:38) — produced a 429 with `Retry-After: 300`. So it is not per access token, and the
  ceiling is roughly 20–25 per 10 min, not ~50. 30 s flat is 20 per 10 min: the timer alone sits
  at the ceiling and a few popover opens or Refreshes tip it over. The owner chose to keep 30 s
  (2026-09-16); ticket 05's backoff is therefore load-bearing, not a corner case. Also: opening the
  popover has no cooldown (spec: immediate), and one open landed 0.75 s after a timer tick and
  issued a second request — 05 or 09 may want a short cooldown on popover-open too.
- **Polling through a lockout does not extend it.** The app kept polling at 30 s (plus a dozen
  popover opens and Refreshes) and every request got a 429 — until 23:47:18, five seconds after
  the 300 s mark (23:42:13.79 → 23:47:13.79; a request at 23:47:13.52 was 0.27 s too early and
  still got a 429). `Retry-After` is honoured to the second, and retries during it are ignored
  rather than punished. So 05's backoff is about not wasting requests, not about avoiding a
  longer ban.
- `poll(.timer)` after a fetch is the only re-arm; if a future change adds an early return before
  it, polling dies silently. The `fetchGeneration` guard exists so a cancelled fetch's completion
  cannot clear a newer fetch's handle.
- The popover placeholder now shows a 429 as nothing at all (Snapshot stays, age grows). That is
  exactly the Stale case 05 renders.
