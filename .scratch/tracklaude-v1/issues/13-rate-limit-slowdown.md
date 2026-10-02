# 13: Rate-limit slowdown (v1.0.1)

**What to build:** after a 429 the app stops looking hung and stops re-provoking the limit.
Observed 2026-10-02 on the owner's machine: for hours about half of all polls drew a 429
(`Retry-After: 0`), the backoff climbed to 8 min with Refresh greyed out, and the stretches
without a reading reached 15–16 min. The usage endpoint's budget (~20–25 requests per
10 min) is per account and shared; at 30 s this app alone spends 20, and after one success
it snapped back to 30 s and drew the next 429 within a minute.

**Blocked by:** 12 v1.0 cut (found during it; ships as v1.0.1)

**Status:** ready-for-agent

- [ ] Backoff cap 600 s → 300 s (`Backoff.cap`)
- [ ] For 30 min after the last 429 the timer cadence is 120 s (`PollScheduler.rateLimitedInterval`,
      `slowdownPeriod`); wake, popover open and Refresh still fetch at once
- [ ] `AppModel.lastRateLimit` set on every 429, kept across Sign out (the budget is the account's)
- [ ] Tests for both; spec › Polling and README updated
- [ ] Released as v1.0.1; on the real app the poll log shows 120 s spacing after a 429

## Comments
