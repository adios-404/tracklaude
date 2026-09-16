# 06: Full popover

**What to build:** Clicking the menu bar shows every Window Anthropic reports: 5-hour, 7-day, then per-model 7-day Windows sorted by name, each with the Window name, a horizontal bar (red ≥ 90, orange ≥ 80, accent otherwise), the percentage, `resets in 2h14m`, and the absolute time in the user's locale (weekday added when more than 24 h away). Per-model rows appear only when present in the Snapshot. A used ↔ remaining segmented toggle flips every percentage and the menu bar together; the choice persists across launches. Clean, informative, no settings window.

**Blocked by:** 03 Live 5-hour readout

**Status:** done (2026-09-17, commits 6b93e82, d4c33c0, e8b699f)

- [x] Popover view-model is a pure function of (Snapshot, mode, now, locale) with tests for row order, per-model presence/absence, colours at 79/80/89/90, absolute-time formatting under and over 24 h
- [x] Remaining mode inverts percentages everywhere and is stored in UserDefaults
- [x] Layout reviewed at the default popover width with 2, 3 and 5 rows — no truncation, no overflow
- [x] All-null Snapshot renders a single "No usage windows reported" row rather than an empty popover

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

**2026-09-17 — implemented.** Core: `State/PopoverRows` — `PopoverRows.render(snapshot:remaining:
now:locale:timeZone:)` → `PopoverReadout` (`.rows([PopoverRow])` or `.noWindows`, whose text is
`PopoverReadout.noWindowsMessage`). A `PopoverRow` is `{ name, percent, tone, resetsIn?, resetsAt? }`
with `Tone` = `.normal / .warning / .critical`; `Identifiable` by name. 12 tests (121 total).
`Window.percent(remaining:)` is the one rounding rule for the menu bar and the rows. Executable:
`UsageRowsView` (rows + `UsageBar`, own file), `PopoverView` builds the readout with
`.autoupdatingCurrent` locale/time zone, the used ↔ remaining `Picker` sits below the rows
(only while a Snapshot exists), and `AppModel.showsRemaining` is backed by the UserDefaults key
`showsRemaining`; the `MenuBarExtra` label reads it too. Popover width is fixed at 300 pt.

**Verified on the real app** (pids 26513 / 30085): rows for 5-hour, 7-day and the per-model
Windows; the owner confirmed the layout and toggled Remaining; the menu bar flipped
`17% · 38m` → `83% · 38m` within a second of the click (AX title sampled once a second, no poll in
between); a relaunch came up in the persisted mode (`18% · 41m` with `showsRemaining = 1`).
The 2 / 3 / 5-row layout check was done by rendering the real `UsageRowsView` off-screen with
`ImageRenderer` in a scratch package (the segmented control does not render there — an
`ImageRenderer` limitation, verified on the app instead). AX still cannot open the popover;
only the owner can look at it.

**Deviations, all deliberate:**

- The colour band uses the *rounded* Utilization: a row that reads "90%" is never orange.
  Spec says "by Utilization"; the number and the colour the user sees always agree instead.
  → Ticket 07: Alerts will presumably cross on raw Utilization, so a row can turn red at 89.5
  a tick before the 90 Alert fires. Either band Alerts on the rounded value too or accept it.
- Remaining mode subtracts the rounded used percentage (`100 − 43`, not `round(57.5)`), so the
  two modes always sum to 100 (spec: "100 − utilization"; the literal reading gives 43 + 58).
- The bar's *fill* follows the displayed percentage (a fuel gauge in remaining mode); only its
  colour is pinned to Utilization. The spec only says colour is by Utilization. Not testable
  from the view-model (it exposes `percent`, the view derives the fill); revisit if it reads
  wrong in use.
- A Window Anthropic did not report (5-hour or 7-day `nil`) gets no row, like per-model ones;
  only a Snapshot with *no* Window at all shows the "No usage windows reported" line.
- `is_active` is still not decoded. The real account's `Fable` per-model Window (0 %, inactive)
  shows as a row — it is reported, so story 6 says show it. If it proves noisy, read `is_active`
  in the decoder and drop inactive 0 % entries there, not in the view-model.
- `Tone.warning` reuses a CONTEXT.md *Avoid* word (for Alert); it names a colour band. Left as is.

Findings that matter downstream:

- Ticket 08: the footer already has Refresh and Quit; the toggle row (`PopoverView.modeToggle`)
  is the natural place for the Launch at Login / Alerts toggles if they go above the divider,
  and `showsRemaining` is the third UserDefaults key the ticket text already anticipates.
- The popover ticks `context.date` once a second into `PopoverRows.render`, so every
  `resets in` text moves; nothing caches rows.

