---
status: accepted
date: 2026-09-16
---

# No auto-update mechanism

tracklaude ships with no updater (no Sparkle, no "check for updates" call). Users update
by `brew upgrade` or by rebuilding from the tagged source. The app's entire network
surface is therefore Anthropic hosts (`claude.ai`, `console.anthropic.com`,
`api.anthropic.com`) plus the loopback callback during sign-in — a property a test can
assert.

## Why

The project exists because the user did not want to trust a self-updating, un-notarized
binary with a credential. A self-updater means every future release, signed by one
person's key, can silently replace the code that was audited. Without a paid Apple
Developer ID there is no notarization backstop. Removing the updater removes that
trust dependency entirely: what you built (or what the tagged CI run built, with a
published SHA-256) is what runs.

## Consequences

- Users don't learn about new versions from the app. The README and Homebrew are the
  channel.
- Adding a passive version check later would reintroduce a non-Anthropic hostname; do it
  only with an explicit opt-in and update this ADR.
