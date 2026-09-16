# 10: Release pipeline and README

**What to build:** Pushing a tag `vX.Y.Z` makes CI build the release configuration, bundle, ad-hoc sign, zip `tracklaude.app`, compute its SHA-256, and publish a GitHub Release with the zip, the `.sha256` file, and auto-generated notes. The README tells a stranger everything they need to trust and install it: what it shows, exactly which hosts it talks to and why, that it holds a narrow OAuth token and never a session cookie, that there is no auto-update and why (link ADRs), the one-time Gatekeeper "right-click → Open" step and why there is no notarization, how to verify the zip's hash against the Release, and how to build from source.

**Blocked by:** 01 Walking skeleton

**Status:** ready-for-agent

- [ ] Tagging `v0.0.1-test` on the private repo produces a Release with `tracklaude-v0.0.1-test.zip` and `.sha256`; the zip unpacks to a launchable app; the tag and Release are deleted afterwards
- [ ] Version in Info.plist equals the tag
- [ ] README covers every item listed above and links the two ADRs and the research report
- [ ] README has a screenshot of the menu bar and popover
