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
