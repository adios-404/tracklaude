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
- [ ] After a real 429 on ≥ 1.0.1 (from 13), `Usage fetch issued (timer)` lines are ~120 s
      apart for 30 min, then back to ~30 s; no lockout longer than 300 s

## Comments

**2026-10-03 — handoff from 12 and 13.** At hand-off 1.0.1 was installed by brew, signed in,
Alerts on (permission granted), Launch at Login on; the 5-hour window read 26 %. Default-level
(`Df`) log lines are what the app writes; they are kept for days, not weeks, so check within a
few days of a crossing. If the Alert never fires at 80 %, compare `AlertDecision` with the
first-sighting rule in ticket 07's Comments before calling it a bug.
