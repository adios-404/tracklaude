# 13: Rate-limit slowdown (v1.0.1)

**What to build:** after a 429 the app stops looking hung and stops re-provoking the limit.
Observed 2026-10-02 on the owner's machine: for hours about half of all polls drew a 429
(`Retry-After: 0`), the backoff climbed to 8 min with Refresh greyed out, and the stretches
without a reading reached 15–16 min. The usage endpoint's budget (~20–25 requests per
10 min) is per account and shared; at 30 s this app alone spends 20, and after one success
it snapped back to 30 s and drew the next 429 within a minute.

**Blocked by:** 12 v1.0 cut (found during it; ships as v1.0.1)

**Status:** done (2026-10-03, commits f8f1b50, 86c5742; Release v1.0.1; homebrew-tap PR #5) — live observation moves to 14

- [x] Backoff cap 600 s → 300 s (`Backoff.cap`)
- [x] For 30 min after the last 429 the timer cadence is 120 s (`PollScheduler.rateLimitedInterval`,
      `slowdownPeriod`); wake, popover open and Refresh still fetch at once
- [x] `AppModel.lastRateLimit` set on every 429, kept across Sign out (the budget is the account's)
- [x] Tests for both; spec › Polling and README updated
- [x] Released as v1.0.1 — [ ] the 120 s spacing after a real 429 is not yet observed → 14

## Comments

**2026-10-03 — closed.** Evidence for the problem, from the dev build's log 16:29–00:17:
511 fetches, 176 refused with 429 (`Retry-After: 0` every time), 18:00–22:00 about half of
each hour's polls; longest stretches without a reading 15 min (22:14–22:29) and 16 min
(00:01–00:17, ended by the reinstall). A 30 min gap at 17:11 was sleep, not a hang.
Something else on the account shares the budget (Usage4Claude is installed but was not
running; not identified). Fix: `PollScheduler.nextFetch` takes `lastRateLimit`; the timer
cadence is 120 s while it is < 30 min old; wake, popover open and Refresh still fetch at
once; `Backoff.cap` 300 s. 152 tests. The README's polling paragraph now says all of this
in plain words. Not yet seen live because no 429 has happened on 1.0.1 — ticket 14.
