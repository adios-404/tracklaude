---
status: accepted
date: 2026-09-16
---

# The app holds its own narrow-scope OAuth refresh token

tracklaude signs the user in once via OAuth/PKCE in their default browser (scope
`user:profile`, using the public client id that Claude Code ships with) and stores the
resulting refresh token as its own Keychain item. It never handles a claude.ai
`sessionKey` cookie and never reads or writes Claude Code's `Claude Code-credentials`
Keychain item.

## Considered options

- **Paste the claude.ai `sessionKey` cookie** (Usage4Claude's default). Rejected: a full
  session cookie is far more powerful than the app needs, and the `claude.ai/api/...`
  endpoints require impersonating a browser's headers to get past Cloudflare — fragile and
  ToS-grey.
- **Borrow Claude Code's token from its Keychain item.** Attractive because the app would
  hold no secret of its own. Rejected after inspection (2026-09-16): the stored access
  token is frequently expired (Claude Code only refreshes when *it* makes a request), so
  the app would have to refresh it; refresh tokens rotate, so the app would then have to
  write the new pair back into Claude Code's item in Claude Code's own JSON layout, racing
  Claude Code's own refreshes. A bug there logs the user out of Claude Code. That is a
  worse trust property than holding a narrow token of our own.
- **In-app WKWebView login.** Rejected: leaves a copy of claude.ai cookies in the app's
  WebKit store on disk.

## Consequences

- The app needs the `network.server` entitlement for the OAuth loopback callback
  (`http://localhost:<port>/callback`), used only during sign-in.
- Whether Anthropic permits third parties to use Claude Code's public client id is an
  open policy question. If it is ever revoked, sign-in breaks and the cookie path becomes
  the fallback to reconsider; nothing else in the app changes.
- Refresh tokens expire after roughly a week of non-use; a user who hasn't run the app
  for that long must sign in again.
