# Security policy

tracklaude holds a refresh token for your Claude account. Report security problems
privately, not in a public issue.

## How to report

Use GitHub's private vulnerability reporting: **Report a vulnerability** on this
repository's **Security and quality** tab, or
<https://github.com/adios-404/tracklaude/security/advisories/new>. Only you and the
maintainer can see the report.

Say which version and macOS you tested, what an attacker gains, and how to reproduce it.
**Do not include a real token, cookie or password, not even your own.** Anthropic tokens
start with `sk-ant-`; keep that prefix and cut the rest (`sk-ant-ort01-…`).

There is no bug bounty, and no promised response time: tracklaude has one maintainer.

## In scope

- **The Credential:** sign-in (PKCE, the `state` check), the Keychain item
  `com.adios404.tracklaude` / `credential`, refresh, and Sign out deleting the item.
- **Log redaction:** a token, `Bearer` value or token field reaching the unified log.
- **Network surface:** any host but `claude.ai`, `console.anthropic.com` and
  `api.anthropic.com`, or anything sent beyond what the README lists.
- **The loopback sign-in listener:** reachable from another machine, accepting the wrong
  `state`, or still listening after sign-in.
- **The sandbox:** any entitlement beyond `app-sandbox`, `network.client` and `network.server`.
- **Release integrity:** a zip that does not match its `.sha256` or the hash its CI run
  printed, a Homebrew cask pointing at other bytes, or a way to publish a build the release
  workflow did not make.

## Not in scope

- Anthropic's services (`claude.ai`, the OAuth and usage endpoints, Claude Code): use
  Anthropic's [responsible disclosure policy](https://www.anthropic.com/responsible-disclosure-policy).
- The public OAuth client id the app shares with Claude Code. Whether Anthropic permits
  that is an open question, stated in
  [ADR-0001](https://github.com/adios-404/tracklaude/blob/main/docs/adr/0001-own-oauth-credential.md):
  known, not a vulnerability.
- Ad-hoc signing without notarization, a deliberate trade explained under
  [Trust](https://github.com/adios-404/tracklaude#trust).

## Supported versions

Only the [latest Release](https://github.com/adios-404/tracklaude/releases/latest) gets
fixes; check the problem still happens there. The app never checks for updates, so watch
the repository's Releases to hear about a fix.
