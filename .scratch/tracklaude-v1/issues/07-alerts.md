# 07: Alerts

**What to build:** macOS notifications when any Window first crosses 80, 90 and 100 percent — each once per Window per cycle, where a cycle is identified by the Window's Reset time and a changed Reset time clears what has fired — plus a "5-hour window reset" notification when the 5-hour Window's Reset time changes after its Utilization was at or above 80. An Alerts toggle in the popover; enabling it requests notification permission, and if permission is denied the toggle says so and links to System Settings.

**Blocked by:** 03 Live 5-hour readout

**Status:** ready-for-agent

- [ ] Alert decision is a pure function of (previous state, new Snapshot) returning the Alerts to fire and the new fired-set; tests cover: single crossing, skipping straight from 70 to 95 (fires 80 and 90), no repeat on the next poll, cycle change clears, Reset Alert only when previous ≥ 80, per-model Windows alert independently
- [ ] Notification titles and bodies are exact and name the Window
- [ ] Toggle persists in UserDefaults; off means no permission request and no delivery
- [ ] Permission denied state is visible in the popover with a link to System Settings › Notifications
- [ ] Manual check: with a fixture-driven build or a real crossing, a notification appears once

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

