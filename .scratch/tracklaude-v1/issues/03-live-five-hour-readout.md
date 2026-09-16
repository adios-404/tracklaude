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
