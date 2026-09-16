# Fixtures

Whole HTTP responses (`status line`, headers, blank line, body — CRLF) replayed by
`Fixture.response(_:)`. Only `Content-Type` and `Retry-After` headers are kept.

**Recorded from the real endpoints on 2026-09-16** (credential scrubbed — the responses
never contained one):

| File | How |
|---|---|
| `usage-normal.http` | `GET api.anthropic.com/api/oauth/usage` with a valid access token (Max plan). Note the many unknown top-level keys and the `weekly_scoped` limit whose `resets_at` has no fractional seconds. |
| `usage-401.http` | Same request with a bogus bearer token. |
| `usage-429.http` | The 39th rapid request in a row; `Retry-After: 300`. |
| `usage-html.http` | `GET claude.ai/api/organizations` with no cookie — Cloudflare's challenge page, the shape of any HTML body the app might meet. |
| `oauth-token-response.json` | Token-endpoint body as documented in `research/usage4claude-study.md` §5. |

**Synthetic, derived from the real `usage-normal` body** (the account had no second
per-model Window, no legacy-field data, no null day, and no 5xx to record):

| File | Change from the real body |
|---|---|
| `usage-per-model.http` | Two `weekly_scoped` models (Sonnet 8, Opus 61), one scoped entry with no model, and a legacy `seven_day_sonnet` at 3 % that must lose to `limits[]`. |
| `usage-legacy-per-model.http` | Same, with `limits[]` removed. |
| `usage-all-null.http` | Every Window and `limits[]` null. |
| `usage-5xx.http` | 503 in the same error envelope the real 429 used. |
