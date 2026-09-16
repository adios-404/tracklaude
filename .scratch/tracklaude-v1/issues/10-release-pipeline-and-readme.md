# 10: Release pipeline and README

**What to build:** Pushing a tag `vX.Y.Z` makes CI build the release configuration, bundle, ad-hoc sign, zip `tracklaude.app`, compute its SHA-256, and publish a GitHub Release with the zip, the `.sha256` file, and auto-generated notes. The README tells a stranger everything they need to trust and install it: what it shows, exactly which hosts it talks to and why, that it holds a narrow OAuth token and never a session cookie, that there is no auto-update and why (link ADRs), the one-time Gatekeeper "right-click → Open" step and why there is no notarization, how to verify the zip's hash against the Release, and how to build from source.

**Blocked by:** 01 Walking skeleton

**Status:** ready-for-agent

- [ ] Tagging `v0.0.1-test` on the private repo produces a Release with `tracklaude-v0.0.1-test.zip` and `.sha256`; the zip unpacks to a launchable app; the tag and Release are deleted afterwards
- [ ] Version in Info.plist equals the tag
- [ ] README covers every item listed above and links the two ADRs and the research report
- [ ] README has a screenshot of the menu bar and popover
- [ ] **Keychain prompt after every update is decided and documented.** Finding from ticket 02:
      with ad-hoc signing the Credential item's ACL is bound to the build's code hash, so the
      first launch of every new release asks for the login password twice (once to read, once
      to add the new build to the ACL). The data-protection keychain is not an option
      (`keychain-access-groups` is restricted; macOS refuses to launch an ad-hoc app carrying
      it). Options: (a) keep ad-hoc and say so plainly in the README's install section —
      default, matches the spec's "no Developer ID"; (b) sign releases with a self-signed cert
      whose private key lives in CI secrets — stable identity, but exactly the supply-chain
      property the research report criticised in Usage4Claude; (c) Developer ID if a paid
      account ever appears. Record the choice in the ticket's Comments and, if (b), in an ADR.
- [ ] `make sign` accepts `SIGN_IDENTITY=<name>` (default `-`) so the owner can sign local
      builds with a self-signed cert they trust once, and stop being prompted during
      development. Creating and trusting that cert is a manual, owner-only step; document it
      in the README's "build from source" section.
