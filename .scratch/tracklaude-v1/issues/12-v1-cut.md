# 12: v1.0 cut

**What to build:** tracklaude goes public. The repo flips from private to public, `v1.0.0` is tagged, the Release and tap PR land, and a clean-machine (or clean-user) install via Homebrew is verified end to end: install → Gatekeeper open → sign in → live readout → an Alert → sign out. Every earlier ticket's acceptance criteria are re-checked against the released binary, and the research report's open questions that this project answered are noted in its Comments.

**Blocked by:** 05 Stale and recovery, 08 Footer controls, 09 Trust guarantees, 11 Homebrew tap

**Status:** ready-for-agent

- [ ] All tickets 01–11 marked done
- [ ] Repo visibility set to public (this is the one irreversible step — confirm with the user immediately before doing it)
- [ ] `adios-404/homebrew-tap` set to public as well (same confirmation) — `brew tap` needs it
- [ ] `v1.0.0` Release published with zip and SHA-256; tap PR merged
- [ ] Fresh install via `brew install adios-404/tap/tracklaude` completes the full flow above
- [ ] SHA-256 of the installed app's zip matches the Release's published hash
- [ ] (from 11) `brew install adios-404/tap/tracklaude` installs and launches 0.1.0 on this machine
- [ ] (from 11) After the v1.0.0 tap PR merges, `brew upgrade` moves that install to 1.0.0

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
