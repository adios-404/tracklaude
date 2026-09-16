# tracklaude v1.0 — spec

Status: ready-for-agent
Date: 2026-09-16
Glossary: see `CONTEXT.md`. Decisions: `docs/adr/0001`, `docs/adr/0002`.
Research: `research/usage4claude-study.md` (API surface, response shapes, original's behaviour).

## Problem Statement

I want a glanceable, always-visible readout of how much of my Claude rate limits I've used and
when they reset, so I can pace my work. The existing tool (Usage4Claude) does this, but it's a
self-signed, self-updating binary from a pseudonymous developer that I'm asked to trust with a
full claude.ai session cookie. I can't audit what it does, and any future update can change it
silently. I want the same glanceability from code I own, can read, and can rebuild myself — and I
want to publish it so others in the same position can use it.

## Solution

tracklaude is a macOS menu-bar app (no Dock icon) that shows the 5-hour Window's Utilization
and Time-to-Reset in the menu bar — e.g. `42% · 2h14m` — and, on click, a popover with every
Window Anthropic reports. It signs in once via OAuth in the user's own browser and holds only a
narrow-scope refresh token in its own Keychain item. It polls Anthropic every 30 seconds, fires
Alerts at 80/90/100% and on Reset, has no auto-updater, contacts no host other than Anthropic's,
and is built, tested and released from public source by CI so anyone can verify the binary.

## User Stories

### Seeing usage

1. As a Claude user, I want the 5-hour Window's Utilization in my menu bar, so that I can see at a glance how close I am to the limit without opening anything.
2. As a Claude user, I want the 5-hour Window's Time-to-Reset next to the percentage, so that I know how long until I'm free to continue.
3. As a Claude user, I want the menu bar value to update every 30 seconds, so that what I see is current.
4. As a Claude user, I want to click the menu-bar item and see every Window (5-hour, 7-day, and any per-model 7-day Windows), so that I can also pace weekly usage.
5. As a Claude user, I want each Window row to show a bar, the percentage, a relative Time-to-Reset and the absolute reset time in my locale, so that I can read it whichever way I think about time.
6. As a Claude user, I want per-model Windows to appear only when Anthropic actually reports them, so that the popover isn't cluttered with empty rows.
7. As a Claude user, I want to toggle between "used" and "remaining", so that I can read it the way that suits me.
8. As a Claude user, I want the popover to show when the data was last fetched, so that I know how fresh it is.
9. As a Claude user, I want a manual Refresh button, so that I can force a fetch right now.
10. As a Claude user, I want the display to refresh immediately when I open the popover and when my Mac wakes from sleep, so that I never look at old numbers.
11. As a Claude user, I want the menu bar to show `—` when Anthropic reports no active 5-hour Window, so that the absence is honest rather than a fake 0%.

### Staying informed

12. As a Claude user, I want a notification when any Window first crosses 80%, so that I can slow down in time.
13. As a Claude user, I want a notification when any Window first crosses 90%, so that I know a stop is imminent.
14. As a Claude user, I want a notification when any Window reaches 100%, so that I know I'm blocked.
15. As a Claude user, I want a notification when the 5-hour Window Resets, so that I know I can continue.
16. As a Claude user, I want each threshold Alert to fire only once per Window per cycle, so that I'm not nagged every 30 seconds.
17. As a Claude user, I want to turn Alerts on or off from the popover, so that I can silence them during focused work.

### When things go wrong

18. As a Claude user, I want the last good value to stay visible but dimmed, with a caution glyph and a one-word reason, when a fetch fails, so that I still have the last-known state and know not to trust it fully.
19. As a Claude user, I want the popover to explain exactly what's wrong (not signed in / offline / rate-limited / session expired) and offer the fix (Sign in / Retry), so that I can recover without guessing.
20. As a Claude user, I want the app to back off automatically when Anthropic rate-limits it and resume 30-second polling when allowed, so that it never makes things worse.
21. As a Claude user, I want the app to detect an expired or revoked Credential and prompt me to sign in again, so that a dead token doesn't sit there silently.

### Signing in and trust

22. As a security-conscious user, I want to sign in via my default browser with Anthropic's own login page, so that I never paste a session cookie into a third-party app.
23. As a security-conscious user, I want the app to hold only a narrow-scope refresh token and never a session cookie, so that a compromise of the app can't act as me on claude.ai.
24. As a security-conscious user, I want the Credential stored in the macOS Keychain, not in a plist or file, so that it's protected at rest.
25. As a security-conscious user, I want a Sign out button that deletes the Credential from the Keychain, so that I can revoke the app's access locally at any time.
26. As a security-conscious user, I want the app to contact no host except Anthropic's, so that I can verify there is no telemetry or exfiltration.
27. As a security-conscious user, I want the app to have no auto-updater, so that the code I audited is the code that runs.
28. As a security-conscious user, I want the app to run in the App Sandbox with the minimum entitlements, so that its blast radius is limited if something goes wrong.
29. As a security-conscious user, I want the app to never write the Credential to logs or diagnostic output, so that "help me debug" can't leak it.
30. As a security-conscious user, I want the app never to read or write Claude Code's own Keychain item, so that it can't break my Claude Code login.

### Running it

31. As a Claude user, I want the app to have no Dock icon, so that it lives only in the menu bar.
32. As a Claude user, I want an optional Launch at Login toggle (off by default), so that the tracker is there when I start work if I choose.
33. As a Claude user, I want a Quit item in the popover, so that I can stop it cleanly.
34. As a Claude user, I want the app to pause polling while my Mac sleeps, so that it doesn't wake the machine or queue useless requests.
35. As a Claude user, I want the app to run on macOS 14 or later, so that it works on any reasonably current Mac.

### As a member of the public

36. As a GitHub visitor, I want to read the source and the ADRs, so that I can judge whether to trust it.
37. As a GitHub visitor, I want `brew install adios-404/tap/tracklaude` to work, so that installing is one command.
38. As a GitHub visitor, I want a downloadable `.zip` with a SHA-256 on each GitHub Release, built by public CI from a tag, so that I can verify the binary matches the source.
39. As a GitHub visitor, I want a README that explains the one-time "right-click → Open" Gatekeeper step, why there is no Apple notarization, and what the app does and doesn't send, so that I'm not surprised.
40. As a contributor, I want `swift build` and `swift test` to work with only Xcode Command Line Tools, so that I don't need Xcode to contribute.
41. As a contributor, I want the test suite to run offline in about a second without touching my Keychain or my Claude usage, so that I can run it freely.
42. As a contributor, I want CI to build and test every push, so that I know the main branch is green.
43. As a contributor, I want a `Makefile` that assembles, signs and installs the `.app`, so that "run it locally" is one command.

## Implementation Decisions

### Architecture

- **Two Swift targets.** A library, `TracklaudeCore`, holds all logic and has no dependency on SwiftUI or AppKit. An executable, `tracklaude`, holds the SwiftUI menu-bar UI, the app lifecycle, and the real I/O adapters. Tests target the library only.
- **Two seams, both protocols defined in the library:**
  - `UsageTransport` — performs one HTTPS request and returns status, headers and body. Production adapter wraps `URLSession` (HTTP/3 disabled, 30 s request timeout). Test adapter replays recorded fixtures.
  - `CredentialStore` — load / save / delete the Credential. Production adapter is the Keychain (generic password, service = bundle id `com.adios404.tracklaude`, account `credential`). Test adapter is in-memory.
- **Pure core, injected clock.** Poll scheduling, Time-to-Reset formatting, Alert decisions, menu-bar text and the popover view-model are pure functions of (latest Snapshot, previous state, now). Every one takes `now` as a parameter; nothing calls `Date()` directly.
- **One state machine drives the app.** States: `signedOut`, `signingIn`, `polling(Snapshot?)`, `stale(lastSnapshot, reason)`, `backingOff(until)`. Reasons for Stale: `offline`, `rateLimited`, `sessionExpired`, `serverError`. The UI renders the state; the state machine decides transitions. This is the thing ticket-level tests exercise most.

### Sign-in (per ADR-0001)

- OAuth 2.0 authorization-code flow with PKCE (S256) in the user's default browser. Authorize at `claude.ai/oauth/authorize`, exchange and refresh at `console.anthropic.com/v1/oauth/token` (JSON body), scope `user:profile`, client id = the public one Claude Code ships with.
- Loopback callback server bound to **loopback only** (`127.0.0.1` and `::1`, not all interfaces — a deliberate improvement over the original), port 1456 with fallback 1458, listening only for the duration of a sign-in, accepting only `/callback` with the expected `state`. Serves a one-line "signed in, you can close this tab" page.
- Stores only the refresh token (prefix `sk-ant-ort01-`) in `CredentialStore`. Access tokens live in memory only.
- On 401 from the usage endpoint: refresh once, retry once; if refresh fails → `stale(.sessionExpired)` and the popover offers Sign in. Rotated refresh tokens are written back to `CredentialStore` immediately.
- Sign out deletes the Keychain item and returns to `signedOut`.

### Fetching usage

- `GET api.anthropic.com/api/oauth/usage` with `Authorization: Bearer <access>` and `anthropic-beta: oauth-2025-04-20`. No browser-impersonating headers anywhere in the app.
- Response decoded leniently: every Window optional; `five_hour`, `seven_day`, `seven_day_opus`, `seven_day_sonnet` each `{utilization: 0–100, resets_at: ISO-8601 with fractional seconds}`; `limits[]` entries with `kind == "weekly_scoped"` and a `scope.model.display_name` become per-model Windows. Legacy per-model fields that are `utilization == 0 && resets_at == nil` are treated as absent. Unknown keys ignored.
- Every successful decode becomes a Snapshot with the fetch time.

### Polling

- 30 s flat while in `polling`. Timer suspended on sleep (`NSWorkspace.willSleepNotification`), immediate fetch on wake and on popover open; manual Refresh fetches immediately with a 5 s cooldown.
- On HTTP 429: enter `backingOff` with exponential delay 60 s → 120 → 240 → capped at 600 s, honouring `Retry-After` if present; any success returns to 30 s.
- On network failure: `stale(.offline)`, keep polling at 30 s.
- On 5xx or undecodable body: `stale(.serverError)`, keep polling.
- Ticket #1 measures how quickly the endpoint reflects new messages; if it proves coarser than 30 s this section's interval is revisited, not the architecture.

### Menu bar

- Text: `<utilization>% · <time-to-reset>` for the 5-hour Window, e.g. `42% · 2h14m`. Under an hour: `14m`. Under a minute: `<1m`. No 5-hour Window in the Snapshot: `—`.
- Stale: same text, dimmed (secondary label colour), followed by `⚠` and one word: `offline`, `limited`, `expired`, `error`. Signed out: `⚠ sign in`.
- When "remaining" mode is on, the percentage shown is `100 − utilization`.
- Icon: a small SF Symbol gauge glyph before the text; monochrome, follows menu-bar appearance.

### Popover

- Rows, in order: 5-hour, 7-day, then per-model 7-day Windows sorted by name. Each row: Window name, horizontal bar, percentage, `resets in 2h14m`, `at 3:45 PM` (locale short time; adds the weekday when > 24 h away).
- Bar colour by Utilization: ≥ 90 red, ≥ 80 orange, else accent.
- Below the rows: used ↔ remaining segmented toggle.
- Stale / signed-out banner above the rows with the plain-English reason and a single action button (Sign in / Retry).
- Footer: "Updated 12 s ago", then buttons: Refresh · Launch at Login (toggle) · Alerts (toggle) · Sign out · Quit. No separate settings window, no preferences file beyond the two toggles (stored in UserDefaults; they are not secrets).

### Alerts

- Thresholds 80, 90, 100. An Alert fires when a Window's Utilization crosses a threshold upward *and* that threshold hasn't already fired for the current cycle. A cycle is identified by the Window's Reset time; a changed Reset time clears the fired set.
- Reset Alert: fires for the 5-hour Window when its Reset time changes and the previous Utilization was ≥ 80 (i.e. a Reset that actually mattered).
- Delivered via `UNUserNotificationCenter`; permission requested on first enable; if denied, the toggle shows that and links to System Settings.

### Packaging and distribution

- SwiftPM only. `Makefile` targets: `build`, `test`, `bundle` (assemble `tracklaude.app` with Info.plist — `LSUIElement`, `LSMinimumSystemVersion 14.0`, bundle id — and icon), `sign` (ad-hoc, with entitlements: `app-sandbox`, `network.client`, `network.server`), `install` (copy to `/Applications`), `zip`.
- GitHub Actions: on push/PR → `swift build` + `swift test` on a macOS 14 runner. On tag `v*` → build, bundle, sign, zip, compute SHA-256, create GitHub Release with both attached.
- Homebrew: a separate `adios-404/homebrew-tap` repo with a cask pointing at the release zip and its SHA-256; the release workflow opens a PR against the tap bumping the version.
- Repo goes public at v1.0.

### Logging

- `os.Logger` with subsystem = bundle id. A redaction helper strips anything matching `sk-ant-[a-z0-9]{2,5}-[A-Za-z0-9_-]{20,}` and `Bearer …` before any message is logged. No log files written by the app.

## Testing Decisions

- **What a good test looks like here:** feed the core a recorded Anthropic response (or a hand-built Snapshot) plus a fixed `now`, and assert on what the user would see or hear — menu-bar text, popover rows, which Alerts fire, what the next state is, when the next poll is scheduled. Never assert on internal calls, timers, or private state.
- **Fixtures:** real responses recorded once in ticket #1 (with the credential scrubbed) and stored under the test target: a normal Snapshot, one with per-model Windows, one with all Windows null, a 401, a 429 with `Retry-After`, a 5xx, an HTML body.
- **Modules tested (all in `TracklaudeCore`):** usage decoding; the app state machine (every transition above); poll scheduling and backoff; Time-to-Reset formatting (boundaries: 59 s, 60 s, 59 min, 24 h, 7 d); menu-bar text in every state; Alert decisions (crossing, once-per-cycle, cycle reset, Reset Alert condition); popover view-model ordering and colours; the OAuth PKCE pair generation and callback `state` check; the log redactor.
- **Not tested:** SwiftUI view bodies, the real Keychain adapter, the real URLSession adapter, the loopback server's socket handling (covered by ticket #1's manual tracer-bullet run instead).
- **Prior art:** none in this repo (greenfield). Convention adopted: Swift Testing (`@Test`), one test file per core module, fixtures as files not string literals, fakes are plain structs/classes — no mocking library.
- **One property test:** the executable's compiled binary contains no hostname other than `claude.ai`, `console.anthropic.com`, `api.anthropic.com`, `localhost` / `127.0.0.1` — a `strings`-based check in CI backing user story 26.

## Out of Scope

- Codex / OpenAI or any second provider.
- Session-cookie auth, in-app WebView login, reading Claude Code's credentials.
- Multiple accounts or organisations.
- Auto-update or version checks of any kind (ADR-0002).
- Localisation beyond English; icon style/size options; colour themes.
- Overage / extra-usage dollar tracking; usage history or charts.
- Apple notarization / Developer ID signing (no paid account; revisit if one appears).
- Diagnostics export.
- iOS, widgets, Shortcuts, CLI output.

## Further Notes

- The public OAuth client id is Claude Code's; whether Anthropic tolerates third-party use is an open question (ADR-0001). If sign-in ever starts failing with an `invalid_client` error, that's the first suspect.
- Refresh tokens appear to expire after ~7 days of non-use (observed 2026-09-16 on Claude Code's own token). A user who leaves the app closed for a week signs in again; the app should say so plainly rather than show a generic error.
- The original's cadence data (60 s → 600 s smart backoff) is in the research report if 30 s flat ever needs revisiting.
- Ticket #1 is the tracer bullet: OAuth sign-in → Keychain → one real usage fetch → menu-bar text, running sandboxed and ad-hoc signed. It also records the fixtures and measures endpoint freshness. Everything else builds on a proven end-to-end path.
