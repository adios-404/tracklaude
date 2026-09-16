# 02: Sign in with Claude

**What to build:** The popover shows a "Sign in with Claude" button. Clicking it opens the user's default browser on Anthropic's OAuth page; after they approve, the browser lands on a local "Signed in — you can close this tab" page, the app's popover switches to "Signed in", and the refresh token is stored as the app's own Keychain item. This ticket is the proof that Keychain writes and the loopback callback work inside the App Sandbox with ad-hoc signing — if either does not, record the finding and revisit the sandbox decision here, not later. Follows ADR-0001 exactly: PKCE S256, scope `user:profile`, Claude Code's public client id, refresh token only in the `CredentialStore`, access token in memory only.

**Blocked by:** 01 Walking skeleton

**Status:** done (2026-09-16, commits 11f1da8, b2a09e9 + review fixes)

- [x] `CredentialStore` protocol in core with an in-memory test adapter and a Keychain production adapter (generic password, service = bundle id, account `credential`)
- [x] PKCE verifier/challenge generation and `state` generation are pure core functions with tests
- [x] Callback server binds to loopback only (127.0.0.1 and ::1), port 1456 with fallback 1458, listens only during sign-in, rejects any request whose `state` does not match, stops after one accepted callback
- [x] Code exchange against `console.anthropic.com/v1/oauth/token` succeeds through the `UsageTransport` seam; a test drives the exchange with a recorded/fake response
- [x] After sign-in the Keychain item exists (verified with `security find-generic-password -s com.adios404.tracklaude`, value not printed) and the popover shows "Signed in"
- [x] Relaunching the app finds the Credential and shows "Signed in" without asking again
- [x] Sandbox stays on; if Keychain or loopback fails under sandbox, the failure and the chosen fallback are written to the ticket's Comments before any entitlement is changed

## Comments

**2026-09-16 — implemented.** Every box verified on the installed, sandboxed, ad-hoc-signed
app: browser landed on "Signed in — you can close this tab", `security find-generic-password
-s com.adios404.tracklaude` shows one `genp` item (`acct=credential`, login keychain), the
listener was gone afterwards (`lsof` on 1456/1458 empty), and a relaunch of the same build
showed "Signed in" with no prompt. 18 core tests, ~1 s, offline.

Findings worth knowing:

- **Keychain ACL is bound to the ad-hoc code hash.** The first launch of a *rebuilt* binary
  (new cdhash) triggered two macOS password prompts before it could read the item — one to
  read, one to add the new build to the item's ACL. Same build afterwards: silent. Consequence
  for releases: every update will ask once. Not a sandbox failure, so no entitlement changed.
  Probed the fix the same day: `kSecUseDataProtectionKeychain` reads fine but `SecItemAdd`
  fails with "A required entitlement is not present", and adding `keychain-access-groups`
  makes macOS refuse to launch the app at all (restricted entitlement, needs a provisioning
  profile). Dead end under ad-hoc signing. The only way to stop the prompt is a stable
  signing identity (a self-signed code-signing cert, as Usage4Claude does, or Developer ID) —
  the owner's call, ticket 10.
- **`allowLocalEndpointReuse` stays on.** Probed with BSD sockets (macOS 27): the port a
  server actively closed sits in TIME_WAIT for 2×MSL = 30 s, so without reuse a retry inside
  that window burns the 1458 fallback and a second retry fails. Cost: if the flag maps to
  `SO_REUSEPORT` (unverified — `NWListener` refuses to start from a bare CLI, EINVAL), two
  tracklaude instances signing in at once could split callbacks. Accepted.
- **Deviations from the spec text:** a third seam, `CallbackListener`, alongside
  `UsageTransport` and `CredentialStore`, so the flow is testable without sockets. And an
  interim `AuthState` (`signedOut / signingIn / signedIn / failed`) in the executable until
  ticket 04/05 build the spec's state machine in core. The log redactor (spec "Logging") is
  not built yet; nothing logs today. Ticket 09.
- **Endpoint freshness measurement and usage fixtures** belong to ticket 03 (first real usage fetch).
- **CLT quirk #2:** a test that imports both `Testing` and `Foundation` fails to build under
  Command Line Tools (`_Testing_Foundation` ships without its Swift module); `make test`
  now passes `-disable-cross-import-overlays` in the CLT-only flags.
