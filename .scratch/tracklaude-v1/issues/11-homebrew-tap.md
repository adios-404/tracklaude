# 11: Homebrew tap

**What to build:** `brew install adios-404/tap/tracklaude` installs the app. A separate repo `adios-404/homebrew-tap` holds a cask pointing at the GitHub Release zip and its SHA-256. The release workflow from ticket 10 opens a pull request against the tap bumping version and hash, so a release is: tag, merge the tap PR.

**Blocked by:** 10 Release pipeline and README

**Status:** ready-for-agent

- [ ] Tap repo exists with a cask that passes `brew audit --cask`
- [ ] Release workflow opens the bump PR automatically (needs a token with write access to the tap repo, stored as a repository secret — set up via `/wizard` if the user has to do it)
- [ ] `brew install adios-404/tap/tracklaude` on this machine installs and launches the app
- [ ] `brew upgrade` after a second test release moves to the new version
- [ ] README's install section shows the brew command first

## Comments

**2026-09-17 — handoff from ticket 10.** The Release asset names are fixed:
`tracklaude-vX.Y.Z.zip` and `tracklaude-vX.Y.Z.zip.sha256` under
`https://github.com/adios-404/tracklaude/releases/download/vX.Y.Z/`; the `.sha256` file is
`shasum` format (`<hex>  tracklaude-vX.Y.Z.zip`), so the cask's `sha256` is `cut -d' ' -f1`
of it. The release job is `.github/workflows/release.yml`; the tap PR step belongs after
*Publish GitHub Release* and needs a token with write access to `adios-404/homebrew-tap`
as a repository secret (the job's own token is `contents: write` on this repo only — keep it
that way). Releases are ad-hoc signed and not notarized, so the cask should expect
quarantine: either document `--no-quarantine` or leave the README's Gatekeeper step in
place for brew users too. README › Install currently says "Homebrew is coming; for now:" —
replace that with the brew command first, keep the zip path as the second option.
Hyphenated tags publish as pre-releases; `releases/latest` skips them, so a cask pinned to
`latest` is safe. Also: the account's usage-endpoint budget is shared with something else
(ticket 10's findings) — a 429 during your end-to-end is probably not the app.

**2026-10-03 — parked mid-ticket (owner hit usage limit).** Done: `ea658b4`/`ee455cf` pushed,
CI green (run 37048098501). Tagged `v0.1.0` → Release run 37048260594 green; Release has
`tracklaude-v0.1.0.zip` + `.sha256` (`6ba3f5e1…dedefa`, matches a local `shasum` of the
downloaded zip). The tap job opened homebrew-tap PR #1 (hash only, version was already
0.1.0); the tap's audit passed; merged (squash). So boxes 1, 2, 5 are satisfied.
Not done: `brew install` / `brew upgrade` — both repos are private, so Homebrew can't
download the zip. Owner agreed (2026-10-02) to move those two checks into ticket 12, which
makes the repos public; plan there: brew-install 0.1.0, release v1.0.0, merge the tap PR,
`brew upgrade`. Remaining for this ticket: tick boxes, move the two checks to 12's
checklist, set Status done, handoff note on 12.
