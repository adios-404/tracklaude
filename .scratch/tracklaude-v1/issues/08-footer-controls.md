# 08: Footer controls

**What to build:** The popover footer is complete: Refresh (from 04), Launch at Login toggle backed by `SMAppService` (off by default, reflects the real system status on each open), Alerts toggle (from 07), Sign out, and Quit. Sign out deletes the Keychain item, drops the in-memory access token, cancels polling, and returns the app to signed-out (`⚠ sign in` in the menu bar, Sign in button in the popover). Everything the app persists is exactly: one Keychain item, and two UserDefaults booleans plus the used/remaining mode.

**Blocked by:** 06 Full popover, 07 Alerts

**Status:** ready-for-agent

- [ ] Launch at Login toggle registers/unregisters with `SMAppService.mainApp` and shows the "requires approval" state when macOS reports it
- [ ] Sign out removes the Keychain item (verified with `security find-generic-password`, item absent) and the app is fully signed out without relaunch
- [ ] Sign in after Sign out works in the same run
- [ ] Quit exits cleanly with no lingering process
- [ ] Footer fits on one line at the default popover width

## Comments

**2026-09-17 — handoff from ticket 07.** The Alerts toggle already exists as
`PopoverView.alertsToggle` (checkbox + denied line with an "Open System Settings" button), bound
to `AppModel.alertsEnabled` (UserDefaults `alertsEnabled`). Move it into the footer if the spec's
one-line footer is what you build; the denied line needs its own row either way. On Sign out,
also reset `AppModel.alertState = AlertState()` next to dropping the session, so a later sign-in
gets the quiet first sighting rather than a Reset Alert from another account's Windows. The
permission re-read is `AppModel.refreshAlertPermission()`, called from the popover's `onAppear`.
