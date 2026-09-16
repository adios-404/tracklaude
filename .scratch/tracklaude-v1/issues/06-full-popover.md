# 06: Full popover

**What to build:** Clicking the menu bar shows every Window Anthropic reports: 5-hour, 7-day, then per-model 7-day Windows sorted by name, each with the Window name, a horizontal bar (red ≥ 90, orange ≥ 80, accent otherwise), the percentage, `resets in 2h14m`, and the absolute time in the user's locale (weekday added when more than 24 h away). Per-model rows appear only when present in the Snapshot. A used ↔ remaining segmented toggle flips every percentage and the menu bar together; the choice persists across launches. Clean, informative, no settings window.

**Blocked by:** 03 Live 5-hour readout

**Status:** ready-for-agent

- [ ] Popover view-model is a pure function of (Snapshot, mode, now, locale) with tests for row order, per-model presence/absence, colours at 79/80/89/90, absolute-time formatting under and over 24 h
- [ ] Remaining mode inverts percentages everywhere and is stored in UserDefaults
- [ ] Layout reviewed at the default popover width with 2, 3 and 5 rows — no truncation, no overflow
- [ ] All-null Snapshot renders a single "No usage windows reported" row rather than an empty popover
