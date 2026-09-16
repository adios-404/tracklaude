# 09: Trust guarantees

**What to build:** The properties the README will promise are enforced by tests, not prose. A log redactor strips any `sk-ant-…` token and any `Bearer …` value before a message reaches `os.Logger`, and the app writes no log files. A CI check runs `strings` over the built binary and fails if any hostname appears other than `claude.ai`, `console.anthropic.com`, `api.anthropic.com`, `localhost`, `127.0.0.1`. A CI check fails if the signed app's entitlements are anything other than app-sandbox, network.client, network.server.

**Blocked by:** 03 Live 5-hour readout

**Status:** ready-for-agent

- [ ] Redactor is a pure function with tests for `sk-ant-oat01-…`, `sk-ant-ort01-…`, `Bearer …`, JSON `"refresh_token":"…"`, and a message with no secret (unchanged)
- [ ] Every log call site goes through the redactor (grep-level check in CI that no direct `Logger` call bypasses it)
- [ ] Hostname allowlist check runs in CI on the release-configuration binary and is green
- [ ] Entitlements check runs in CI and is green
- [ ] Both checks demonstrably fail when a stray hostname or entitlement is introduced (verified once, then reverted)
