# 11: Homebrew tap

**What to build:** `brew install adios-404/tap/tracklaude` installs the app. A separate repo `adios-404/homebrew-tap` holds a cask pointing at the GitHub Release zip and its SHA-256. The release workflow from ticket 10 opens a pull request against the tap bumping version and hash, so a release is: tag, merge the tap PR.

**Blocked by:** 10 Release pipeline and README

**Status:** ready-for-agent

- [ ] Tap repo exists with a cask that passes `brew audit --cask`
- [ ] Release workflow opens the bump PR automatically (needs a token with write access to the tap repo, stored as a repository secret — set up via `/wizard` if the user has to do it)
- [ ] `brew install adios-404/tap/tracklaude` on this machine installs and launches the app
- [ ] `brew upgrade` after a second test release moves to the new version
- [ ] README's install section shows the brew command first
