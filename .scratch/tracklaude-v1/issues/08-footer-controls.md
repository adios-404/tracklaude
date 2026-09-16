# 08: Footer controls

**What to build:** The popover footer is complete: Refresh (from 04), Launch at Login toggle backed by `SMAppService` (off by default, reflects the real system status on each open), Alerts toggle (from 07), Sign out, and Quit. Sign out deletes the Keychain item, drops the in-memory access token, cancels polling, and returns the app to signed-out (`⚠ sign in` in the menu bar, Sign in button in the popover). Everything the app persists is exactly: one Keychain item, and two UserDefaults booleans plus the used/remaining mode.

**Blocked by:** 06 Full popover, 07 Alerts

**Status:** ready-for-agent

- [ ] Launch at Login toggle registers/unregisters with `SMAppService.mainApp` and shows the "requires approval" state when macOS reports it
- [ ] Sign out removes the Keychain item (verified with `security find-generic-password`, item absent) and the app is fully signed out without relaunch
- [ ] Sign in after Sign out works in the same run
- [ ] Quit exits cleanly with no lingering process
- [ ] Footer fits on one line at the default popover width
