# 05: Stale and recovery

**What to build:** When a fetch fails the user keeps the last good value — dimmed, with `⚠` and one word (`offline`, `limited`, `expired`, `error`) — and the popover shows a plain-English banner with a single fix button (Retry, or Sign in). The app state machine is completed: `signedOut`, `signingIn`, `polling(Snapshot?)`, `stale(lastSnapshot, reason)`, `backingOff(until)`. Network failure → `stale(.offline)` and keep polling at 30 s. HTTP 429 → `backingOff` with 60 → 120 → 240 → 600 s cap, honouring `Retry-After`, any success returns to 30 s. 5xx or undecodable body → `stale(.serverError)`. 401 → refresh the access token once and retry once; if the refresh fails the Credential is treated as expired → `stale(.sessionExpired)`, and Sign in from the banner runs ticket 02's flow again. Rotated refresh tokens are written to the `CredentialStore` immediately. Signed out shows `⚠ sign in` in the menu bar.

**Blocked by:** 04 30-second polling

**Status:** done (2026-09-17, commits d61c260, 45c878d, 26fc4f7, 015eea6, 34bd36a + review fixes)

- [x] Every state transition listed above has a test driven through the transport seam with the recorded failure fixtures
- [x] Menu-bar text builder covers every Stale reason and signed-out; dimming is a view-model flag, not a view decision
- [x] Backoff schedule tested including `Retry-After` precedence and reset-on-success
- [x] 401 path tested: refresh succeeds → retry succeeds; refresh fails → sessionExpired; token rotation persisted
- [x] Popover banner text for each reason is exact and a single button performs the right action
- [x] Manual check: turn Wi-Fi off → menu bar dims with `offline` within 30 s; turn on → recovers within 30 s

## Comments

**2026-09-16 — handoff from ticket 03.** `UsageFetchError` already separates `unauthorized`,
`rateLimited(retryAfter:)`, `serverError(status:)`, `undecodable(status:)`, `unexpectedStatus`;
map the last three to `.serverError`. `OAuthRefresh.refresh` throws `OAuthTokenError.httpStatus(400)`
for a dead Credential (`invalid_grant`); today `AppModel.restoreCredential` shows that as
"Sign-in failed" with an HTTP-status string — the spec wants a plain "session expired, sign in
again" (refresh tokens die after ~7 days idle). The recorded `usage-429.http` carries
`Retry-After: 300`; honour it over the 60 s first step.

**2026-09-16 — handoff from ticket 04.** Polling lives in `AppModel.poll(_:)` (one entry point,
pure `PollScheduler` decides). To add `backingOff(until)`: give `PollState` a case carrying the
date and have `nextFetch` return it for `.timer` (and probably for `.popoverOpened` / `.manualRefresh`
too — a Refresh during backoff must not extend the lockout). `UsageFetchError.rateLimited(retryAfter:)`
already carries `Retry-After`. **Budget reality:** 23 requests / 10 min across two access tokens →
429 + `Retry-After: 300`, so the limit is per account and ~20–25 / 10 min; at the owner's chosen
30 s cadence the timer alone is at the ceiling, and your backoff will be exercised in normal use. Observed: retries during a `Retry-After: 300`
lockout do not extend it (cleared at +300 s to the second despite ~12 requests inside it), so
`backingOff(until:)` should simply trust the header.
Sleep/wake has not been exercised on a real sleep yet — close the lid once during your Wi-Fi
check and look for `Sleeping: polling suspended` / `Woke: polling resumes` / `fetch issued (wake)`.
`fetchFailure: String?` and `AuthState` are still the interim shape for you to replace.

**2026-09-17 — implemented.** Core, all pure and all tested (47 new tests; 109 total, offline):
`State/AppState` (`AppState`, `StaleReason`, `applying(_:now:)` is the whole transition table),
`State/Backoff` (60→120→240→480→600 cap; `Retry-After` wins outright), `State/PopoverBanner`
(message + `Action?` with its button title), `Usage/FetchResult` (`FetchFailure` = one case per
Stale reason), `Usage/UsageSession` (an actor created from a Credential — loaded on launch or produced by a
sign-in — holding it and the access token; refreshes before the first fetch on a Credential-only
launch, and does 401 → refresh once → retry once, persisting a rotated Credential *before* the
retry). `MenuBarText.render(state:remaining:now:)` returns a
`MenuBarLabel { text, isDimmed }`. `PollState` gained `.backingOff(until:)`, for which every trigger
returns `max(until, now)`, and `isManualRefreshAllowed` took a `state` parameter so the Refresh
button is grey for the whole lockout. Tests use a new `ScriptedTransport` fake (a queue of replies,
each a response or a thrown error) beside the single-reply `FakeTransport`.

Executable: `AppModel` runs on `AppState` + `UsageSession`; `AuthState`, `fetchFailure` and the
in-model `accessToken` are gone. A fetch result is applied only while `state.isSignedIn`, so a
reply landing after a sign-in started cannot drag the app back. The popover shows the banner above
the (dimmed, still present) rows; the footer's Refresh is hidden while nothing can be fetched
(signed out, signing in, expired session) and disabled during a lockout. The menu-bar label uses
`isDimmed` → `.secondary`.

**Observed run** (pid 9156): Wi-Fi off 00:09:57 → `polling → stale(offline)` at 00:10:03 (6 s);
failures logged at 00:10:33 / 00:11:03 / 00:11:33 — still 30 s cadence through the outage; Wi-Fi
on → `stale(offline) → polling` at 00:12:03, the next tick. Menu bar read `70% · 1h26m` before
and `74% · 1h16m` after via the AX title. The Keychain item is untouched. Not exercised on the real
app: a 429 (would need ~25 requests in 10 min; the schedule and `Retry-After` precedence are
tested and the state is logged as `backingOff(until HH:MM:SS, 429 #n)` when it happens), a real
sessionExpired (needs a dead Credential), and sleep/wake (still needs a lid close — see ticket 04).
Do not turn Wi-Fi off from an agent session: it cuts the agent's own connection (learned the hard
way, 2026-09-17).

**Deviations, all deliberate:**

- `backingOff` carries `(Snapshot?, until:, consecutiveRateLimits:)`, not just `until` — the
  readout must survive a lockout, and the schedule needs to know how many 429s in a row this is.
  The count lives only in `backingOff`; any non-429 failure in between restarts at 60 s (only
  success is required to reset; this keeps the other states free of a counter).
- `StaleReason.rateLimited` exists (spec lists it) but `applying` never produces
  `.stale(_, .rateLimited)`; a 429 always becomes `backingOff`, whose `staleReason` reads as
  `.rateLimited` for the menu bar (`limited`) and banner.
- The rate-limit banner has **no** button, only a live countdown ("Retrying in 4 min 59 s.").
  A Retry during a lockout is refused and (without `Retry-After`) would double the delay, so
  offering one would be a trap. Sign in / Retry appear on every other reason as the spec says.
- An expired session **stops polling** (`pollState` → `.signedOut`): every fetch would fail the
  same refresh. Sign in from the banner re-enters `polling` with the last Snapshot kept.
- Refresh failures are classified by status: 400/401/403 → `sessionExpired`; 429 →
  `rateLimited(nil)`; other statuses/undecodable → `serverError`; a thrown transport error →
  `offline` (the Credential may be fine; telling the user to sign in again would be wrong). A
  Keychain *save* failure for a rotated Credential is reported as `sessionExpired` — the server
  has already retired the old one, so the next silent launch cannot succeed.
- `signInFailure: String?` stays in `AppModel` beside the state: a failed sign-in lands in
  `.signedOut` with the reason on the banner ("Sign-in failed: …"); a *cancelled* one returns to
  the state it started from (an expired session keeps its readout).
- `Retry-After` sets the delay but does not reset the 429 count: 429 (`Retry-After: 300`) then
  429 (no header) waits 120 s, not 60. The spec is silent; the count is "429s in a row", which
  that is.
- A Keychain *read* failure at launch is not a session problem: `restoreCredential` logs it and
  the signed-out banner reads "Sign-in failed: the saved sign-in could not be read (…)".
  (Review caught the first cut mapping it to `sessionExpired`; `UsageSession` no longer reads
  the store at all.)
- The poll timer sleeps in ≤ 30 s chunks and bumps `model.now` between them, so Time-to-Reset in
  the menu bar keeps moving through a 10-minute backoff.
- `PopoverView` also dims the rows while Stale (secondary colour) — not in the spec, cheap, and
  consistent with the menu bar.

Findings that matter downstream:

- **The whole UI is now a function of `model.state`**; ticket 06 should build the rows from
  `state.lastSnapshot` and keep the banner as the first element. Ticket 08's Sign out is
  `session = nil`, `store.delete()`, `transition(to: .signedOut)` — the session exists only
  while signed in.
- Review noted (not acted on): the log redactor is ticket 09's; the two new
  `error.localizedDescription` log lines in `AppModel` carry no token but must go through it
  then. `AppModel.pollState` / `describe` are pure functions of `AppState` living in the
  executable; move them into core if 08/09 want them tested.
- `AppState.applying` is the only transition table for fetch results; sign-in/out transitions live
  in `AppModel.signIn()` / `restoreCredential()`. Alerts (07) should be decided *before*
  `transition(to:)` in `fetchUsage`, comparing `state.lastSnapshot` with the fresh one.
- Popover-open still has no cooldown; it fetches on every open unless a fetch is in flight.
  With backoff now real this costs at most one 429 → a 60 s pause, which is the designed outcome.
