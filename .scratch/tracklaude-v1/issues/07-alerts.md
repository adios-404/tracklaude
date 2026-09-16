# 07: Alerts

**What to build:** macOS notifications when any Window first crosses 80, 90 and 100 percent — each once per Window per cycle, where a cycle is identified by the Window's Reset time and a changed Reset time clears what has fired — plus a "5-hour window reset" notification when the 5-hour Window's Reset time changes after its Utilization was at or above 80. An Alerts toggle in the popover; enabling it requests notification permission, and if permission is denied the toggle says so and links to System Settings.

**Blocked by:** 03 Live 5-hour readout

**Status:** ready-for-agent

- [ ] Alert decision is a pure function of (previous state, new Snapshot) returning the Alerts to fire and the new fired-set; tests cover: single crossing, skipping straight from 70 to 95 (fires 80 and 90), no repeat on the next poll, cycle change clears, Reset Alert only when previous ≥ 80, per-model Windows alert independently
- [ ] Notification titles and bodies are exact and name the Window
- [ ] Toggle persists in UserDefaults; off means no permission request and no delivery
- [ ] Permission denied state is visible in the popover with a link to System Settings › Notifications
- [ ] Manual check: with a fixture-driven build or a real crossing, a notification appears once
