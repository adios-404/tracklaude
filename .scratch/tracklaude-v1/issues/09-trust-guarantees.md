# 09: Trust guarantees

**What to build:** The properties the README will promise are enforced by tests, not prose. A log redactor strips any `sk-ant-…` token and any `Bearer …` value before a message reaches `os.Logger`, and the app writes no log files. A CI check runs `strings` over the built binary and fails if any hostname appears other than `claude.ai`, `console.anthropic.com`, `api.anthropic.com`, `localhost`, `127.0.0.1`. A CI check fails if the signed app's entitlements are anything other than app-sandbox, network.client, network.server.

**Blocked by:** 03 Live 5-hour readout

**Status:** ready-for-agent

- [ ] Redactor is a pure function with tests for `sk-ant-oat01-…`, `sk-ant-ort01-…`, `Bearer …`, JSON `"refresh_token":"…"`, and a message with no secret (unchanged)
- [ ] Every log call site goes through the redactor (grep-level check in CI that no direct `Logger` call bypasses it)
- [ ] Hostname allowlist check runs in CI on the release-configuration binary and is green
- [ ] Entitlements check runs in CI and is green
- [ ] Both checks demonstrably fail when a stray hostname or entitlement is introduced (verified once, then reverted)

## Comments

**2026-09-17 — handoff from ticket 08.** Everything the app persists is now: the Keychain item
(`com.adios404.tracklaude` / `credential`), UserDefaults `alertsEnabled`, `launchAtLogin`
(write-only mirror), `showsRemaining`, and — outside the app — the system login-items entry
that `SMAppService` keeps. Sign out removes the Keychain item only (verified with `security`);
the login item and defaults survive it by design. Hostnames in the binary: the popover now also
opens `x-apple.systempreferences:` and calls `SMAppService.openSystemSettingsLoginItems()`, no
new network hosts; the `strings` property test should still pass. See 08's Comments for the 429
budget note before promising a polling rate.
