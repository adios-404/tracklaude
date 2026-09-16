# 05: Stale and recovery

**What to build:** When a fetch fails the user keeps the last good value — dimmed, with `⚠` and one word (`offline`, `limited`, `expired`, `error`) — and the popover shows a plain-English banner with a single fix button (Retry, or Sign in). The app state machine is completed: `signedOut`, `signingIn`, `polling(Snapshot?)`, `stale(lastSnapshot, reason)`, `backingOff(until)`. Network failure → `stale(.offline)` and keep polling at 30 s. HTTP 429 → `backingOff` with 60 → 120 → 240 → 600 s cap, honouring `Retry-After`, any success returns to 30 s. 5xx or undecodable body → `stale(.serverError)`. 401 → refresh the access token once and retry once; if the refresh fails the Credential is treated as expired → `stale(.sessionExpired)`, and Sign in from the banner runs ticket 02's flow again. Rotated refresh tokens are written to the `CredentialStore` immediately. Signed out shows `⚠ sign in` in the menu bar.

**Blocked by:** 04 30-second polling

**Status:** ready-for-agent

- [ ] Every state transition listed above has a test driven through the transport seam with the recorded failure fixtures
- [ ] Menu-bar text builder covers every Stale reason and signed-out; dimming is a view-model flag, not a view decision
- [ ] Backoff schedule tested including `Retry-After` precedence and reset-on-success
- [ ] 401 path tested: refresh succeeds → retry succeeds; refresh fails → sessionExpired; token rotation persisted
- [ ] Popover banner text for each reason is exact and a single button performs the right action
- [ ] Manual check: turn Wi-Fi off → menu bar dims with `offline` within 30 s; turn on → recovers within 30 s

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
