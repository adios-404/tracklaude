# 08: Footer controls

**What to build:** The popover footer is complete: Refresh (from 04), Launch at Login toggle backed by `SMAppService` (off by default, reflects the real system status on each open), Alerts toggle (from 07), Sign out, and Quit. Sign out deletes the Keychain item, drops the in-memory access token, cancels polling, and returns the app to signed-out (`⚠ sign in` in the menu bar, Sign in button in the popover). Everything the app persists is exactly: one Keychain item, and two UserDefaults booleans plus the used/remaining mode.

**Blocked by:** 06 Full popover, 07 Alerts

**Status:** done (2026-09-17, commits d6edbae, ff6d901 + review fixes)

- [x] Launch at Login toggle registers/unregisters with `SMAppService.mainApp` and shows the "requires approval" state when macOS reports it
- [x] Sign out removes the Keychain item (verified with `security find-generic-password`, item absent) and the app is fully signed out without relaunch
- [x] Sign in after Sign out works in the same run
- [x] Quit exits cleanly with no lingering process
- [x] Footer fits on one line at the default popover width

## Comments

**2026-09-17 — handoff from ticket 07.** The Alerts toggle already exists as
`PopoverView.alertsToggle` (checkbox + denied line with an "Open System Settings" button), bound
to `AppModel.alertsEnabled` (UserDefaults `alertsEnabled`). Move it into the footer if the spec's
one-line footer is what you build; the denied line needs its own row either way. On Sign out,
also reset `AppModel.alertState = AlertState()` next to dropping the session, so a later sign-in
gets the quiet first sighting rather than a Reset Alert from another account's Windows. The
permission re-read is `AppModel.refreshAlertPermission()`, called from the popover's `onAppear`.

**2026-09-17 — implemented.** Core: `State/LaunchAtLoginRow.swift` — `LaunchAtLoginStatus`
(mirrors `SMAppService.Status`, with `isOn`) and `LaunchAtLoginRow.render(status:failure:)` →
`{ isOn, note?, offersSystemSettings }`; `PopoverBanner.render` gained `signOutFailure:`. 6 new
tests (142 total). Executable: `Adapters/LoginItem` (wraps `SMAppService.mainApp`; `notFound`
outside a bundle), `AppModel.setLaunchAtLogin` / `refreshLaunchAtLogin` / `signOut`, and the
popover: two checkbox rows above the divider (Launch at Login, Alerts — each with its own note
line via `noteLine`), footer `Updated · Refresh · Sign out · Quit` at `.controlSize(.small)`.
Sign out is offered only while signed in; it drops the session, timer, in-flight fetch, queued
Alert delivery and `alertState` at once, transitions to `signedOut`, then deletes the Credential
after the in-flight fetch unwinds (a mid-refresh rotation would otherwise resurrect the item);
the next sign-in awaits that delete before it saves.

**Verified on the real app** (pid 58395, owner clicking; the computer-use index could not see
the app at all). Launch at Login on → macOS posted "Login Item Added", status `enabled`, no
note; off → `notRegistered`. Sign out: `security find-generic-password` watched at 1 Hz read
*present → absent (02:23:26) → present (02:23:33)* around a Sign out at 02:23:25 and a same-run
Sign in; the log shows `backingOff(429 #5) → signedOut`, `Signed out: Credential removed`,
`signedOut → signingIn → polling`. Quit: `pgrep` empty. UserDefaults after: `alertsEnabled`,
`launchAtLogin`, `showsRemaining` — exactly the three keys the ticket names. Footer fits on one
line at 300 pt (owner screenshot).

**Deviations, all deliberate:**

- The spec's one-line footer lists both toggles; at 300 pt that cannot fit with "Updated 12 s
  ago" and three buttons. The toggles are checkbox rows above the divider (ticket 07's layout,
  now with Launch at Login above Alerts); the footer proper is one line. Ticket 07's handoff
  already conceded each toggle needs a note row.
- **`SMAppService.mainApp.status` reads `notFound` for a never-registered app** (verified
  2026-09-17, macOS 27, ad-hoc signed, in /Applications): `notFound` from launch until the
  first `register()`, which succeeds; `unregister()` then leaves `notRegistered`. Both render as
  plain off; a register that really fails throws and its reason shows under the checkbox.
- `launchAtLogin` in UserDefaults is a write-only mirror of "reads as on": the spec counts two
  toggle booleans, but the truth is the system's login-items store (which persists outside the
  app — a third place, unavoidable with `SMAppService`).
- `requiresApproval` reads as on with "Waiting for approval in System Settings › Login Items."
  and an Open System Settings button (`SMAppService.openSystemSettingsLoginItems()`). Not
  reachable on this machine; rendering is unit-tested, the button is not.
- A Keychain delete failure on Sign out still signs the app out (session gone) and says so on
  the banner ("Signed out, but the saved sign-in could not be removed from the Keychain: …").

**Review** (`/code-review`, two axes): fixed — doc comments, the `launchAtLogin` comment that
contradicted the write, an unused `CaseIterable`, a double log line, `status.isOn` instead of
rendering a row for one Bool, the sign-out-delete vs sign-in-save ordering, cancelling a queued
delivery on Sign out. Not changed: Sign out is not an `AppState` event (it is the bare
`.signedOut` case; nothing to test); the three failure Strings stay separate; the Alerts note
text stays in the view (pre-existing, one for a later tidy).

Findings for the next tickets: a fresh sign-in resets the 429 backoff count and polls at once —
the rate budget is per account, so signing out and in during a lockout spends it (seen at
02:23: sign-in from `backingOff #5` went straight to `polling`). Harmless for one user, but
ticket 09's trust story should not promise the app never over-polls. The app was in a 429 loop
(#1 → #5, `Retry-After: 0`) again this session at normal 30 s cadence: the account's budget is
tighter than the spec assumed; ticket 12 may want 60 s.
