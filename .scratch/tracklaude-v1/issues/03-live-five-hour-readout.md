# 03: Live 5-hour readout

**What to build:** Once signed in, the app performs one real usage fetch and the menu bar shows the 5-hour Window as `42% · 2h14m` (`14m` under an hour, `<1m` under a minute, `—` when the Window is absent). This is the first end-to-end tracer through the seam: Credential → access token → `GET api.anthropic.com/api/oauth/usage` with `Authorization: Bearer` and `anthropic-beta: oauth-2025-04-20` → Snapshot → menu-bar text. It also records the response fixtures that every later ticket's tests use, and measures how quickly the endpoint reflects new messages so the 30-second decision rests on evidence.

**Blocked by:** 02 Sign in with Claude

**Status:** ready-for-agent

- [ ] `UsageTransport` protocol in core with a URLSession production adapter (HTTP/3 off, 30 s timeout) and a fixture-replaying test adapter
- [ ] Usage decoding is lenient: every Window optional; `limits[]` entries with `kind == weekly_scoped` and a model display name become per-model Windows; legacy per-model fields with `utilization == 0 && resets_at == nil` are treated as absent; unknown keys ignored; tests cover each case
- [ ] Time-to-Reset formatter is a pure function of (reset, now) with tests at the boundaries: 59 s, 60 s, 59 min, 60 min, 24 h, 7 d, past
- [ ] Menu-bar text builder is a pure function with tests for present / absent 5-hour Window and remaining mode
- [ ] Real fixtures recorded (credential scrubbed) and committed: normal, with per-model Windows, all-null, 401, 429 with Retry-After, 5xx, HTML body
- [ ] Endpoint freshness measured: send a few messages in Claude while polling every 10 s; note in Comments how long until utilization changes. If coarser than 30 s, say so — the interval, not the design, gets revisited
- [ ] Installed app shows a real value in the menu bar within a few seconds of launch

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
