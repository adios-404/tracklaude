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
