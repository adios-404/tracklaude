# 02: Sign in with Claude

**What to build:** The popover shows a "Sign in with Claude" button. Clicking it opens the user's default browser on Anthropic's OAuth page; after they approve, the browser lands on a local "Signed in — you can close this tab" page, the app's popover switches to "Signed in", and the refresh token is stored as the app's own Keychain item. This ticket is the proof that Keychain writes and the loopback callback work inside the App Sandbox with ad-hoc signing — if either does not, record the finding and revisit the sandbox decision here, not later. Follows ADR-0001 exactly: PKCE S256, scope `user:profile`, Claude Code's public client id, refresh token only in the `CredentialStore`, access token in memory only.

**Blocked by:** 01 Walking skeleton

**Status:** ready-for-agent

- [ ] `CredentialStore` protocol in core with an in-memory test adapter and a Keychain production adapter (generic password, service = bundle id, account `credential`)
- [ ] PKCE verifier/challenge generation and `state` generation are pure core functions with tests
- [ ] Callback server binds to loopback only (127.0.0.1 and ::1), port 1456 with fallback 1458, listens only during sign-in, rejects any request whose `state` does not match, stops after one accepted callback
- [ ] Code exchange against `console.anthropic.com/v1/oauth/token` succeeds through the `UsageTransport` seam; a test drives the exchange with a recorded/fake response
- [ ] After sign-in the Keychain item exists (verified with `security find-generic-password -s com.adios404.tracklaude`, value not printed) and the popover shows "Signed in"
- [ ] Relaunching the app finds the Credential and shows "Signed in" without asking again
- [ ] Sandbox stays on; if Keychain or loopback fails under sandbox, the failure and the chosen fallback are written to the ticket's Comments before any entitlement is changed
