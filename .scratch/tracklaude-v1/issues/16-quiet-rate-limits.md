# 16: Quiet rate limits (v1.0.2)

**What to build:** stop showing `⚠ limited` over a reading that is still good. The owner
saw it on v1.0.1 over a 24 s old reading (2026-10-03, screenshot: "46% · 3h23m ⚠ limited",
banner "Retrying in 40 s", Refresh greyed). v1.0.1's log 00:58–01:39: 45 fetches, 8 refused,
all `Retry-After: 0`; 01:14–01:31 the app sent only 5 requests in 17 min and every one was
refused — the refusals do not depend on this app's rate, so ticket 13's slowdown alone
could not make them go away.

**Blocked by:** 13 Rate-limit slowdown

**Status:** done (2026-10-03, commits d3b3ead, 9500551; Release v1.0.2; homebrew-tap PR #7)

- [x] `AppState.staleReason(now:)`: backing off is `.rateLimited` only when the last reading is ≥ 10 min old (`rateLimitGrace`) or absent; other reasons unchanged
- [x] Menu bar, banner and row dimming all use it — a 429 over a fresh reading renders as live
- [x] `Backoff.cap` 300 → 120 s; a positive Retry-After still wins
- [x] Tests; README and spec updated
- [x] Released as v1.0.2 and running on the owner's machine (then superseded by v1.0.3)

## Comments

**2026-10-03 — closed.** 155 tests at release. Whether a quiet 429 ever turns into a visible
`⚠ limited` (only after 10 min without a good reading) is left to ticket 14's observations.
