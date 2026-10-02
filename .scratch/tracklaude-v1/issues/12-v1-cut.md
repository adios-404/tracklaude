# 12: v1.0 cut

**What to build:** tracklaude goes public. The repo flips from private to public, `v1.0.0` is tagged, the Release and tap PR land, and a clean-machine (or clean-user) install via Homebrew is verified end to end: install → Gatekeeper open → sign in → live readout → an Alert → sign out. Every earlier ticket's acceptance criteria are re-checked against the released binary, and the research report's open questions that this project answered are noted in its Comments.

**Blocked by:** 05 Stale and recovery, 08 Footer controls, 09 Trust guarantees, 11 Homebrew tap

**Status:** done (2026-10-03; v1.0.0 c65b605, v1.0.1 86c5742; homebrew-tap PRs #3, #5) — the Alert step moves to 14

- [x] All tickets 01–11 marked done
- [x] Repo visibility set to public (this is the one irreversible step — confirm with the user immediately before doing it)
- [x] `adios-404/homebrew-tap` set to public as well (same confirmation) — `brew tap` needs it
- [x] `v1.0.0` Release published with zip and SHA-256; tap PR merged (and v1.0.1, ticket 13)
- [x] Fresh install via `brew install adios-404/tap/tracklaude` completes the full flow above — all but the Alert, which waits on a real 80 % crossing → 14
- [x] SHA-256 of the installed app's zip matches the Release's published hash
- [x] (from 11) `brew install adios-404/tap/tracklaude` installs and launches 0.1.0 on this machine
- [x] (from 11) After the v1.0.0 tap PR merges, `brew upgrade` moves that install to 1.0.0

## Comments

**2026-10-03 — handoff from ticket 11.** `v0.1.0` is published (non-pre-release) and the tap
cask points at it with the CI build's hash; the whole tag → Release → tap PR → audit chain
ran green once. Two of 11's checks landed here because private repos 404 an unauthenticated
download (probed 2026-10-03: the release zip URL and the tap URL both 404 logged-out).
Suggested order once both repos are public: brew-install 0.1.0 on this user (checks 11's
install box) → bump `VERSION` to `1.0.0`, tag `v1.0.0`, merge the tap PR → `brew upgrade`
(11's upgrade box) → the clean-user fresh install of 1.0.0 for the full flow. The release
workflow refuses a tag that disagrees with `VERSION`. Before brew-installing on this user,
remove the dev build from `/Applications` (if `make run` put one there) so the cask's `app`
stanza doesn't collide.

**2026-10-03 — closed.** What ran, in order, all on the owner's machine (macOS 26):

- Pre-public sweep: `gitleaks` over all 62 commits and the tap — no leaks. Hand-checked hits:
  test-fake `sk-ant-…` tokens, Claude Code's public OAuth client id (by design), an old
  scratchpad path, and Usage4Claude's developer email from their public signing cert in the
  research report (removed from the tree in ff2cc58; history keeps it). Commits all use the
  GitHub no-reply address. Owner confirmed, then both repos went public; the release zip
  and tap URLs went from 404 to 200 logged-out.
- Tap audit switched to `--online` (it fetches the cask url), then given
  `HOMEBREW_GITHUB_API_TOKEN` after a PR audit failed on the runner's anonymous 60/h GitHub
  API quota — not on the cask.
- `brew install` 0.1.0 (re-tapped from GitHub; the local tap was a stale clone of an old
  scratchpad path) → Gatekeeper prompt → owner's Open Anyway → 2 Keychain prompts → polling.
  Homebrew 7 auto-trusts a cask installed by its full name (`~/.homebrew/trust.json`).
- `v1.0.0` → tap PR #3 → `brew upgrade` → 1.0.0. Homebrew warned "signer changed"; Gatekeeper
  did **not** prompt for the upgrade, the Keychain did (2 prompts, from securityd's log).
- Ticket 13 found and shipped as `v1.0.1` (tap PR #5).
- Fresh flow on 1.0.1: Keychain item deleted, `brew uninstall --zap`, `brew install` →
  Gatekeeper prompted (fresh install) → owner Open Anyway → Sign in → `25% · 4h4m` →
  Sign out ("Credential removed", no fetch while signed out) → Sign in again. **Zero**
  Keychain prompts on that path. Installed app is file-identical to the Release zip's app;
  cached zip hash `ae4e4e39…` = the Release's.
- Re-checked against the installed 1.0.1: Info.plist (id, LSUIElement, min 14.0, version),
  exactly the three entitlements (`check-entitlements.sh` on the installed app), hostname
  allowlist on the installed binary, 30 s cadence and popover-open fetches in the log,
  relaunch keeps sign-in with no prompt, Quit leaves no process, Launch at Login enabled,
  notification permission granted. Not re-run by hand on the release: the Wi-Fi-off
  check (05; agent must not toggle Wi-Fi) and the popover layout (06) — the owner used the
  popover during the flow; both are unchanged code since their tickets.

**Deviations.** Docs were wrong in two ways and are fixed (README, Release notes of 1.0.0
and 1.0.1, cask caveats, tap README): Gatekeeper *may* re-ask after an update (it did not
for brew upgrade), and the Keychain asks twice after an *update* with an existing sign-in,
never after a first sign-in. `brew uninstall --zap` did not reset preferences: cfprefsd
still held the domain and wrote it into the new container (`alertsEnabled` stayed 1).
The CGEvent popover click from ticket 10 no longer opens the popover and `osascript` lacks
assistive access, though compiled helpers pass `AXIsProcessTrusted` — AX from Swift reads
the menu-bar title fine. The owner did the clicks.

**Research report's open questions this project answered:** the usage endpoint's rate
budget is per account (~20–25 requests / 10 min) and shared, `Retry-After: 0` happens and
must not be honoured literally, and an ad-hoc signed app can live with Gatekeeper and the
Keychain ACL if both are documented where users meet them. Still open: whether Anthropic
permits third-party use of Claude Code's OAuth client id.
