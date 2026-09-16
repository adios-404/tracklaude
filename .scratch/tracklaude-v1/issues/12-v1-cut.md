# 12: v1.0 cut

**What to build:** tracklaude goes public. The repo flips from private to public, `v1.0.0` is tagged, the Release and tap PR land, and a clean-machine (or clean-user) install via Homebrew is verified end to end: install → Gatekeeper open → sign in → live readout → an Alert → sign out. Every earlier ticket's acceptance criteria are re-checked against the released binary, and the research report's open questions that this project answered are noted in its Comments.

**Blocked by:** 05 Stale and recovery, 08 Footer controls, 09 Trust guarantees, 11 Homebrew tap

**Status:** ready-for-agent

- [ ] All tickets 01–11 marked done
- [ ] Repo visibility set to public (this is the one irreversible step — confirm with the user immediately before doing it)
- [ ] `v1.0.0` Release published with zip and SHA-256; tap PR merged
- [ ] Fresh install via `brew install adios-404/tap/tracklaude` completes the full flow above
- [ ] SHA-256 of the installed app's zip matches the Release's published hash
