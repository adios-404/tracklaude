# 19: The Homebrew cask should refuse Intel Macs

**What to fix:** releases are arm64 only (`lipo -info` on v1.0.3's binary, 2026-10-03), but
`adios-404/homebrew-tap`'s `Casks/tracklaude.rb` declares only `depends_on macos: :sonoma`.
On an Intel Mac `brew install` succeeds and the app never opens. One line in the cask,
`depends_on arch: :arm64`, makes Homebrew refuse with a clear message instead.

**Blocked by:** none

**Status:** needs-triage

- [ ] The cask declares `depends_on arch: :arm64`, through a tap pull request so the tap's
      CI audits it
- [ ] `Scripts/bump-cask.sh` and `Scripts/test-bump-cask.sh` still pass with the new line
      (the bump edits only `version` and `sha256`)

## Comments

**2026-10-03.** Found while redesigning the README, which now says "Needs an Apple silicon
Mac (M1 or later)". No app release needed: the tap change stands alone. The alternative,
universal builds, would need `swift build --arch arm64 --arch x86_64` in CI and has not been
tried.
