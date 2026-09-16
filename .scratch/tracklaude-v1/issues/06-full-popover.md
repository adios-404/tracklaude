# 06: Full popover

**What to build:** Clicking the menu bar shows every Window Anthropic reports: 5-hour, 7-day, then per-model 7-day Windows sorted by name, each with the Window name, a horizontal bar (red ≥ 90, orange ≥ 80, accent otherwise), the percentage, `resets in 2h14m`, and the absolute time in the user's locale (weekday added when more than 24 h away). Per-model rows appear only when present in the Snapshot. A used ↔ remaining segmented toggle flips every percentage and the menu bar together; the choice persists across launches. Clean, informative, no settings window.

**Blocked by:** 03 Live 5-hour readout

**Status:** ready-for-agent

- [ ] Popover view-model is a pure function of (Snapshot, mode, now, locale) with tests for row order, per-model presence/absence, colours at 79/80/89/90, absolute-time formatting under and over 24 h
- [ ] Remaining mode inverts percentages everywhere and is stored in UserDefaults
- [ ] Layout reviewed at the default popover width with 2, 3 and 5 rows — no truncation, no overflow
- [ ] All-null Snapshot renders a single "No usage windows reported" row rather than an empty popover

## Comments

**2026-09-16 — handoff from ticket 03.** `Snapshot.perModel` is already sorted by model name.
The real account reports a `Fable` per-model Window at 0 % with `is_active: false`; the decoder
does not read `is_active` yet — add it if you decide inactive 0 % rows should hide. `PopoverView`
holds a placeholder readout to delete. `MenuBarText.render(window:remaining:now:)` is the
per-Window text builder you can reuse for row percentages.

**2026-09-16 — from ticket 04.** The popover body is wrapped in `TimelineView(.periodic(by: 1))`;
pass `context.date` as `now` into your view-model so rows and footer tick together. The footer
row (`UpdatedAgoText` + Refresh + Quit) already exists in `PopoverView.footer(now:)`.

**2026-09-17 — handoff from ticket 05.** `PopoverView` is now: banner (`PopoverBanner.render(
state:signInFailure:now:)` → `model.perform(action)`) → rows → footer, all driven by `model.state`
(`AppState`); `model.snapshot` is `state.lastSnapshot`. Build your rows from that and dim them
while `state.staleReason != nil` (the placeholder already does, with `.secondary`). The menu-bar
label comes from `MenuBarText.render(state:remaining:now:)` → `MenuBarLabel { text, isDimmed }`;
"remaining" is the only parameter still hardcoded (`false`) in `TracklaudeApp` and `PopoverView`.
The footer hides Refresh via `model.canRefresh` and disables it via `model.isRefreshAllowed(now:)`.
