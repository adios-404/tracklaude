# 19: The Homebrew cask should refuse Intel Macs

**What to fix:** releases are arm64 only (`lipo -info` on v1.0.3's binary, 2026-10-03), but
`adios-404/homebrew-tap`'s `Casks/tracklaude.rb` declares only `depends_on macos: :sonoma`.
On an Intel Mac `brew install` succeeds and the app never opens. One line in the cask,
`depends_on arch: :arm64`, makes Homebrew refuse with a clear message instead.

**Blocked by:** none

**Status:** done (2026-10-03, homebrew-tap PR #9; carried into PR #10's 1.0.4 cask)

- [x] The cask declares `depends_on arch: :arm64`, through a tap pull request so the tap's
      CI audits it
- [x] `Scripts/bump-cask.sh` and `Scripts/test-bump-cask.sh` still pass with the new line
      (the bump edits only `version` and `sha256`)

## Comments

**2026-10-03.** Found while redesigning the README, which now says "Needs an Apple silicon
Mac (M1 or later)". No app release needed: the tap change stands alone. The alternative,
universal builds, would need `swift build --arch arm64 --arch x86_64` in CI and has not been
tried.

**2026-10-03, done.** `depends_on arch: :arm64` above `depends_on macos: :sonoma`; local
`brew style` and the tap's `brew audit --cask --strict --online` both passed. Ran
`bump-cask.sh 9.9.9 <hash>` on a copy of the new cask: it rewrote only `version` and
`sha256`. The release's bump PR (#10) was opened after #9 merged, so the 1.0.4 cask has
the line too.

