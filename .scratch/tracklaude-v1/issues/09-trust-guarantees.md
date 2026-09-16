# 09: Trust guarantees

**What to build:** The properties the README will promise are enforced by tests, not prose. A log redactor strips any `sk-ant-…` token and any `Bearer …` value before a message reaches `os.Logger`, and the app writes no log files. A CI check runs `strings` over the built binary and fails if any hostname appears other than `claude.ai`, `console.anthropic.com`, `api.anthropic.com`, `localhost`, `127.0.0.1`. A CI check fails if the signed app's entitlements are anything other than app-sandbox, network.client, network.server.

**Blocked by:** 03 Live 5-hour readout

**Status:** done (2026-09-17, commits 8ac0e5c, da8de96, 6c7b093)

- [x] Redactor is a pure function with tests for `sk-ant-oat01-…`, `sk-ant-ort01-…`, `Bearer …`, JSON `"refresh_token":"…"`, and a message with no secret (unchanged)
- [x] Every log call site goes through the redactor (grep-level check in CI that no direct `Logger` call bypasses it)
- [x] Hostname allowlist check runs in CI on the release-configuration binary and is green
- [x] Entitlements check runs in CI and is green
- [x] Both checks demonstrably fail when a stray hostname or entitlement is introduced (verified once, then reverted)

## Comments

**2026-09-17 — handoff from ticket 08.** Everything the app persists is now: the Keychain item
(`com.adios404.tracklaude` / `credential`), UserDefaults `alertsEnabled`, `launchAtLogin`
(write-only mirror), `showsRemaining`, and — outside the app — the system login-items entry
that `SMAppService` keeps. Sign out removes the Keychain item only (verified with `security`);
the login item and defaults survive it by design. Hostnames in the binary: the popover now also
opens `x-apple.systempreferences:` and calls `SMAppService.openSystemSettingsLoginItems()`, no
new network hosts; the `strings` property test should still pass. See 08's Comments for the 429
budget note before promising a polling rate.

**2026-09-17 — implemented.** Core: `Logging/LogRedactor.swift` — `redact(_:)`, pure; three
patterns: the spec's `sk-ant-[a-z0-9]{2,5}-[A-Za-z0-9_-]{20,}`, `Bearer\s+\S+`, and the JSON
`"access_token"`/`"refresh_token"` fields whatever their value. Replacement is `[redacted]`.
6 tests (148 total). Executable: `AppLog.swift` is the only file that may `import os` or
construct a `Logger`; `notice`/`error`/`fault` take a `String`, redact it, and log it
`.public` (which every call site already asked for). The 18 call sites in `AppModel` and
`AlertNotifier` moved over unchanged in wording. Checks: `Scripts/check-log-redaction.sh`,
`check-hostnames.sh`, `check-entitlements.sh`, run by `make trust` locally and in CI (the
inline entitlements step in `ci.yml` became the script).

**Verified on the real app** (pid 75615): the app's own lines still flow (`Notification
permission: granted`, `State: signedOut → polling`, `Usage fetch issued (timer)`); zero
`sk-ant-`/`Bearer ` strings in the process's whole log window; the sandbox container's
`Logs/` is empty and no non-plist file was written. Each check was broken and restored:
a used `https://telemetry.example.com` + `203.0.113.7` literal (hostname FAIL), an extra
`files.user-selected.read-only` and later `keychain-access-groups` entitlement (FAIL), a
stray `Logger(` and later a `FileHandle.standardError.write` (FAIL).

**Deviations and findings:**

- **The `strings` layer alone is not enough.** Swift stores literals of ≤15 bytes inline in
  the String value, so they never reach the binary's string table: `"127.0.0.1"` is in
  `LoopbackCallbackServer.swift` and `strings -n 3` finds it 0 times (verified 2026-09-17).
  A stray `"sentry.io"` passed the binary check green. The hostname script therefore runs
  the same extraction over `Sources/` as a second layer; both layers share one allowlist.
  Also: an *unused* stray literal is dead-stripped in release, so only used hosts show.
- The hostname extractor's TLD list deliberately omits TLDs that double as ordinary tokens
  (`.app`, `.sh`, `.so`, `.it`, `.in`) — `tracklaude.app` and `check-log-redaction.sh` in a
  comment must not read as hosts. A stray host under one of those would slip through; the
  script's header says so. Runtime-assembled hosts are invisible to both layers by nature.
- The redaction grep also refuses `print`/`NSLog`/`debugPrint`/`dump`/`fputs`, `FileHandle`
  and `.write(to`, which is what enforces "the app writes no log files".
- `Bearer` is matched case-sensitively, as the spec writes it; the OAuth callback `?code=`
  is not redacted (not in the spec's patterns, PKCE-bound and single-use).
- `Regex` is not `Sendable`, so the redactor's patterns are computed statics rebuilt per
  call — fine on a log path.

**Review** (`/code-review`, two axes): fixed — `echo` under `/bin/sh` honouring `\c` (now
`printf`), the redaction script's exit status coming from `grep -v`, the entitlements grep
seeing only `com.apple.security.*` keys (now every `<key>`), the over-claiming header
comment, CI repeating the Makefile's paths (now `make trust`), a missing trailing newline.
Not changed: `AppLog`'s three near-identical bodies (KISS), the raw `String` log category
(pre-existing), `anthropicToken` keeping "token" in its name (it names Anthropic's literal
format, not the domain Credential).

Findings for ticket 10's README: the promises this ticket enforces are exactly — every log
line redacted (story 29), no host outside the five (story 26), entitlements exactly three
(story 28), no log files. It should *not* promise a polling rate (see 08's 429 note), and
it should say the log is `.public` by design so `log show` is readable — the redactor is
the only thing between a Credential and that log, which is why it is tested.
