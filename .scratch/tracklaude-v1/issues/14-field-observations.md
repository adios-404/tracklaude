# 14: Field observations on the released app

**What to build:** nothing — confirm two behaviours of the released app that need a real
event to happen, by reading its log. No code change unless one of them is wrong.

**Blocked by:** None (can start immediately; the events may not have happened yet — if not,
say so and leave it open)

**Status:** ready-for-agent

- [ ] An Alert fired on the brew-installed release (from 12): the 5-hour window crossed 80 %
      with Alerts on. `/usr/bin/log show --predicate 'subsystem == "com.adios404.tracklaude"
      AND category == "alerts"' --last 3d` shows `Alert: … at 80%` and `Delivered: …`, from a
      process whose binary is `/Applications/tracklaude.app` at version ≥ 1.0.1
- [ ] After a real 429 on ≥ 1.0.3 (from 13 and 16), `Usage fetch issued (timer)` lines are
      ~120 s apart for 30 min, then back to ~30 s; no wait longer than 120 s between tries
- [ ] (from 16) During that refusal the menu bar showed no `⚠ limited` while the last good
      reading was under 10 min old — ask the owner, or read `State:` lines for how long the
      refusal lasted (under 10 min means nothing should have been visible)

## Comments

**2026-10-03 — handoff from 12 and 13.** At hand-off 1.0.1 was installed by brew, signed in,
Alerts on (permission granted), Launch at Login on; the 5-hour window read 26 %. Default-level
(`Df`) log lines are what the app writes; they are kept for days, not weeks, so check within a
few days of a crossing. If the Alert never fires at 80 %, compare `AlertDecision` with the
first-sighting rule in ticket 07's Comments before calling it a bug.

**2026-10-03 — updated for v1.0.3.** Ticket 16 cut the backoff cap to 120 s and hid the
warning for 10 min; ticket 17 removed the popover-open fetch, so every fetch in the log is now
`(timer)`, `(wake)` or `(manualRefresh)`.
