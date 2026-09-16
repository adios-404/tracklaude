# 04: 30-second polling

**What to build:** The menu-bar value stays current on its own: a fetch every 30 seconds flat while signed in, none while the Mac sleeps, an immediate fetch on wake, on popover open, and on a Refresh button in the popover (5-second cooldown so a double-click doesn't double-fetch). The popover footer reads "Updated 12 s ago" and ticks.

**Blocked by:** 03 Live 5-hour readout

**Status:** ready-for-agent

- [ ] Poll scheduler is a pure function of (state, now, last fetch, trigger) returning the next fetch time; tests cover steady state, wake, popover-open, manual with and without cooldown
- [ ] Sleep suspends the timer; wake triggers a fetch and resumes the 30 s cadence
- [ ] Opening the popover triggers a fetch; the footer's "Updated N s ago" updates every second while the popover is open
- [ ] Refresh button fetches immediately and is disabled for 5 s afterwards
- [ ] No fetch is ever issued while signed out
- [ ] Running the app for 10 minutes shows fetches at 30 s intervals (observed via the log, credential redacted)
