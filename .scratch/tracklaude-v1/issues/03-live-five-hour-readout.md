# 03: Live 5-hour readout

**What to build:** Once signed in, the app performs one real usage fetch and the menu bar shows the 5-hour Window as `42% · 2h14m` (`14m` under an hour, `<1m` under a minute, `—` when the Window is absent). This is the first end-to-end tracer through the seam: Credential → access token → `GET api.anthropic.com/api/oauth/usage` with `Authorization: Bearer` and `anthropic-beta: oauth-2025-04-20` → Snapshot → menu-bar text. It also records the response fixtures that every later ticket's tests use, and measures how quickly the endpoint reflects new messages so the 30-second decision rests on evidence.

**Blocked by:** 02 Sign in with Claude

**Status:** done (2026-09-16, commits d177e05, a32e0df, 5e7e4bd + review fixes)

- [x] `UsageTransport` protocol in core with a URLSession production adapter (HTTP/3 off, 30 s timeout) and a fixture-replaying test adapter
- [x] Usage decoding is lenient: every Window optional; `limits[]` entries with `kind == weekly_scoped` and a model display name become per-model Windows; legacy per-model fields with `utilization == 0 && resets_at == nil` are treated as absent; unknown keys ignored; tests cover each case
- [x] Time-to-Reset formatter is a pure function of (reset, now) with tests at the boundaries: 59 s, 60 s, 59 min, 60 min, 24 h, 7 d, past
- [x] Menu-bar text builder is a pure function with tests for present / absent 5-hour Window and remaining mode
- [x] Real fixtures recorded (credential scrubbed) and committed: normal, with per-model Windows, all-null, 401, 429 with Retry-After, 5xx, HTML body
- [x] Endpoint freshness measured: send a few messages in Claude while polling every 10 s; note in Comments how long until utilization changes. If coarser than 30 s, say so — the interval, not the design, gets revisited
- [x] Installed app shows a real value in the menu bar within a few seconds of launch

## Comments

**2026-09-16 — handoff from ticket 02.** Already in place: `UsageTransport` protocol
(`Sources/TracklaudeCore/Seams/UsageTransport.swift`), the URLSession production adapter
(`Sources/tracklaude/Adapters/URLSessionTransport.swift`, HTTP/3 off, 30 s timeout) and a
fixture-replaying `FakeTransport` + `Fixture` helper under `Tests/TracklaudeCoreTests/Fakes/`
with fixtures as files in `Tests/TracklaudeCoreTests/Fixtures/`. So the first box is done
except for confirming it against the real endpoint.

Not yet built and needed here: the **refresh grant**. After a relaunch the app holds only the
Credential (refresh token); there is no access token in memory, so the first fetch must
`POST console.anthropic.com/v1/oauth/token` with `{"grant_type":"refresh_token","refresh_token":…,"client_id":…}`
(same endpoint and client id as `OAuthTokenExchange`), keep the access token in `AppModel`
only, and write the rotated refresh token straight back to `CredentialStore`. Expect ~1 s of
Keychain password prompts on the first launch of each rebuilt binary (ticket 02 finding).

**2026-09-16 — implemented.** Menu bar showed `46% · 2h53m` seconds after the first launch of the
installed, sandboxed build; the rotated refresh token was written back (Keychain `mdat` moved at
launch). 47 core tests, offline, ~5 ms. Core additions: `Usage/Snapshot` (`Window`, `ModelWindow`,
`Snapshot`), `Usage/UsageDecoder`, `Usage/TimeToReset`, `Usage/UsageFetch` (+ `UsageFetchError`),
`OAuth/OAuthRefresh` sharing `OAuthTokenEndpoint` with the code exchange. Note: the `AppModel` /
popover wiring rode along in commit 5e7e4bd (a `git add -A` slip), not in its own commit.

Fixtures: **real** — `usage-normal`, `usage-401`, `usage-429` (`Retry-After: 300`), `usage-html`
(Cloudflare page from `claude.ai/api/organizations`, no cookie). **Synthetic, derived from the
real body** — per-model, legacy-per-model, all-null, 5xx, unknown-keys; the account has one
per-model Window (Fable, 0 %) and no way to provoke the others. `Fixtures/README.md` lists which
is which. Recorded with a one-off Python script and its own OAuth grant (two consents were burned
on tooling: python.org's Python 3.14 ships without a CA bundle → use `/usr/bin/python3`).

**Freshness:** poll at 10 s while this Claude Code session was consuming usage. 5-hour
utilization moved 48 → 49 → 50 over six minutes, and the 49 → 50 step fell between two
consecutive 10 s samples, so the endpoint reflects new usage at ≤ 10 s granularity. 30 s is
not coarser than the data; the interval stands.

Findings that matter downstream:

- **The usage endpoint rate-limits per access token, with a rolling budget of roughly 50
  requests per 10 minutes.** 39 back-to-back requests produced a 429 with `Retry-After: 300`,
  which was honoured to the second (cleared at +300 s); 9 further requests at 10 s spacing
  then tripped it again. The installed app fetched fine on its own token during the lockout.
  At 30 s (20 per 10 min) the app has ~2.5× headroom; the manual Refresh cooldown (5 s) is the
  only way a user could burn it. Ticket 04's 10-minute run should confirm zero 429s.
- **`resets_at` jitters sub-second on every response** (`.829695`, `.081712`, `.513556` for the
  same Reset). The decoder truncates to the second (`rounded(.down)`), so a Window's Reset is
  stable in a Snapshot. Ticket 07 must not treat a Reset change of a few seconds as a new cycle
  regardless — compare with a tolerance (a minute is plenty).
- **Cloudflare filters the token endpoint by User-Agent:** `Python-urllib` → 403,
  `curl/8` → 429, a plain UA → 400 (the real `invalid_grant`). CFNetwork's default UA passes;
  the app sets none. If sign-in or refresh ever starts failing with 403/429, check the UA first.
- **The real body has a dozen undocumented keys** (`nimbus_quill`, `tangelo`, `seven_day_cowork`,
  `spend`, `seven_day_breakdown`, …) and a `weekly_scoped` `resets_at` *without* fractional
  seconds. Lenient decoding and the both-forms date parser were both needed on day one.
- **Per-model Windows:** `limits[]` is the source; the legacy `seven_day_opus/sonnet` fields only
  fill a model `limits[]` does not name (a rule the spec did not state; documented in the
  decoder). The real `Fable` entry is 0 % with `is_active: false` and a Reset — per the spec it
  is "reported", so it shows. Ticket 06 may want to hide inactive 0 % rows; `is_active` is not
  decoded yet.
- **A Window with `resets_at: null`** renders as `42%` (no dot, no time) — a lenient extra the
  spec did not define; the real 5-hour Window always had a Reset.
- **Deviations / deferrals:** `UsageFetchError` has an extra `unexpectedStatus(Int)` (found in
  review: a 403 JSON envelope would otherwise decode as an empty Snapshot and show `—`).
  `AppModel` still has the interim `AuthState` plus a `fetchFailure: String?` — ticket 05
  replaces both with the state machine. `PopoverView` got a placeholder readout of every
  Window so the Snapshot could be eyeballed; ticket 06 replaces it. `TracklaudeCore.Window`
  clashes with `SwiftUI.Window`, so SwiftUI files qualify it.
