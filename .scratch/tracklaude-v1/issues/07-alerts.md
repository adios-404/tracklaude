# 07: Alerts

**What to build:** macOS notifications when any Window first crosses 80, 90 and 100 percent — each once per Window per cycle, where a cycle is identified by the Window's Reset time and a changed Reset time clears what has fired — plus a "5-hour window reset" notification when the 5-hour Window's Reset time changes after its Utilization was at or above 80. An Alerts toggle in the popover; enabling it requests notification permission, and if permission is denied the toggle says so and links to System Settings.

**Blocked by:** 03 Live 5-hour readout

**Status:** done (2026-09-17, commits 6796781, e3f07f0, ce95dad + review fixes)

- [x] Alert decision is a pure function of (previous state, new Snapshot) returning the Alerts to fire and the new fired-set; tests cover: single crossing, skipping straight from 70 to 95 (fires 80 and 90), no repeat on the next poll, cycle change clears, Reset Alert only when previous ≥ 80, per-model Windows alert independently
- [x] Notification titles and bodies are exact and name the Window
- [x] Toggle persists in UserDefaults; off means no permission request and no delivery
- [x] Permission denied state is visible in the popover with a link to System Settings › Notifications
- [x] Manual check: with a fixture-driven build or a real crossing, a notification appears once

## Comments

**2026-09-16 — handoff from ticket 03.** Anthropic's `resets_at` jitters sub-second on every
response (`.83`, `.08`, `.51` seen for one Reset). The decoder truncates to the second, but treat
a cycle as new only when the Reset moves by more than a tolerance (a minute), never on exact
inequality.

**2026-09-17 — handoff from ticket 06.** The popover bands its bar colour on the *rounded*
Utilization (`Window.percent(remaining: false)`: 89.5 → red). If Alerts cross on raw Utilization,
a row is red one tick before the 90 Alert fires; consider using the same rounded value so the
colour and the notification agree. `PopoverRows.render` is the row builder if the Alerts toggle
needs a row state. Ticket 05's note still stands: decide Alerts in `AppModel.fetchUsage` before
`transition(to:)`, comparing `state.lastSnapshot` with the fresh one.

**2026-09-17 — implemented.** Core: `State/Alerts.swift` — `AlertDecision.decide(previous:snapshot:)`
→ `(alerts: [Alert], state: AlertState)`. An `Alert` is `{ window, kind (.threshold(80|90|100) |
.reset), percent, resetsAt, fetchedAt }` with computed `title` / `body`. `AlertState.records` is
keyed by Window name (`5-hour`, `7-day`, model name) → `{ resetsAt, percent, fired }`; only the
Windows in the last Snapshot are kept. 13 tests (134 total). Executable: `Adapters/AlertNotifier`
(wraps `UNUserNotificationCenter`; `nil` outside a bundle, where `current()` traps; a delegate
presents banners while the popover has the app frontmost), `AppModel.alertsEnabled` (UserDefaults
key `alertsEnabled`), `AppModel.alertPermission`, and `PopoverView.alertsToggle` (a checkbox
above the divider; when denied, a caption line + "Open System Settings" button).

Texts: `5-hour window at 80%` / `Resets in 2h14m.`; at 100: `Limit reached. Resets in 40m.`;
without a Reset: `No reset time reported.`; Reset: `5-hour window reset` / `Usage is back to 3%.`

**Verified on the real app** (pids 44677 / 45734). The permission alert was presented and the
owner clicked *Don't Allow* first — the denied line and the System Settings button appeared and
the deep link (`x-apple.systempreferences:com.apple.Notifications-Settings.extension`, verified
2026-09-17) opened the Notifications pane. After the owner allowed it there and reopened the
popover, the permission re-read flipped to granted, and a seeded first cycle (temporary, not
committed) made the real 5-hour Window (≥ 90 %) fire `80%` and `90%` once each through the real
decision path; `usernoted` presented both; the Refresh right after fired nothing. Owner confirmed.

**Out-of-ticket fix (6796781):** during this session the running app got a 429 with
`Retry-After: 0` on an ordinary poll, honoured it literally, and re-fetched ~60×/s (22,000
requests in 8 min) until killed. A non-positive Retry-After now falls back to the 60 → 600 s
schedule. Memory updated.

**Deviations, all deliberate:**

- Thresholds cross on the *rounded* Utilization (`Window.percent(remaining: false)`), as ticket
  06 suggested, so a row that turns red and the 90 Alert happen on the same poll.
- The first sighting of a Window (launch, or a per-model Window newly reported) seeds its fired
  set silently and fires nothing — spec says "first crosses", and at launch the user is looking
  at the readout. A Reset (new cycle) does count as crossing from 0, so a post-Reset climb alerts.
- A cycle is new when the Reset moves by more than 60 s (ticket 03's jitter), or flips nil ↔ set.
- `AlertState` is tracked even while the toggle is off, so enabling mid-cycle cannot replay
  crossings already lived through; it is reset on a fresh sign-in (possibly another account).
- The toggle label reads "Alerts at 80, 90 and 100%" rather than the spec footer's bare "Alerts";
  it sits above the divider (ticket 06's suggestion), not in the footer row — ticket 08 owns
  the footer's final arrangement.
- Permission is re-read on every popover open (no prompt), so a fix made in System Settings is
  noticed without a relaunch.

Findings for ticket 08: the toggle row is `PopoverView.alertsToggle`; the two UserDefaults
booleans the spec names are now `alertsEnabled` and the coming `launchAtLogin`, plus
`showsRemaining`. Sign out should also clear `alertState` (do it where `session = nil` lands) so
the next sign-in gets the quiet first sighting. Ad-hoc signing did not stop notification
permission — macOS keyed it on the bundle id and path, and it survived a rebuild.
