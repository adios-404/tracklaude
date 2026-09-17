# 10: Release pipeline and README

**What to build:** Pushing a tag `vX.Y.Z` makes CI build the release configuration, bundle, ad-hoc sign, zip `tracklaude.app`, compute its SHA-256, and publish a GitHub Release with the zip, the `.sha256` file, and auto-generated notes. The README tells a stranger everything they need to trust and install it: what it shows, exactly which hosts it talks to and why, that it holds a narrow OAuth token and never a session cookie, that there is no auto-update and why (link ADRs), the one-time Gatekeeper "right-click → Open" step and why there is no notarization, how to verify the zip's hash against the Release, and how to build from source.

**Blocked by:** 01 Walking skeleton

**Status:** done (2026-09-17, commits 8258254, f73f87b, cfc700a, 730bf5b + this note)

- [x] Tagging `v0.0.1-test` on the private repo produces a Release with `tracklaude-v0.0.1-test.zip` and `.sha256`; the zip unpacks to a launchable app; the tag and Release are deleted afterwards
- [x] Version in Info.plist equals the tag
- [x] README covers every item listed above and links the two ADRs and the research report
- [x] README has a screenshot of the menu bar and popover
- [x] **Keychain prompt after every update is decided and documented.** Finding from ticket 02:
      with ad-hoc signing the Credential item's ACL is bound to the build's code hash, so the
      first launch of every new release asks for the login password twice (once to read, once
      to add the new build to the ACL). The data-protection keychain is not an option
      (`keychain-access-groups` is restricted; macOS refuses to launch an ad-hoc app carrying
      it). Options: (a) keep ad-hoc and say so plainly in the README's install section —
      default, matches the spec's "no Developer ID"; (b) sign releases with a self-signed cert
      whose private key lives in CI secrets — stable identity, but exactly the supply-chain
      property the research report criticised in Usage4Claude; (c) Developer ID if a paid
      account ever appears. Record the choice in the ticket's Comments and, if (b), in an ADR.
- [x] `make sign` accepts `SIGN_IDENTITY=<name>` (default `-`) so the owner can sign local
      builds with a self-signed cert they trust once, and stop being prompted during
      development. Creating and trusting that cert is a manual, owner-only step; document it
      in the README's "build from source" section.

## Comments

**2026-09-17 — handoff from ticket 09.** `make trust` (also a CI step) runs the three
trust checks: log redaction grep, hostname allowlist over the binary *and* `Sources/`, and
the embedded entitlements. Run it in the release job after `make sign` so a release cannot
ship what CI would refuse. README wording that is now backed by a test: "every log line
passes through a redactor that strips `sk-ant-…` tokens and `Bearer` values", "the binary
and source name no host but `claude.ai`, `console.anthropic.com`, `api.anthropic.com`,
`localhost`/`127.0.0.1`", "entitlements are exactly app-sandbox, network.client,
network.server", "no log files". Say plainly what the checks cannot see (a host assembled
at runtime; TLDs like `.app`/`.sh` are excluded from the scan) — the README should invite
source review, not replace it. Do not promise a polling rate (08's 429 finding). The
`x-apple.systempreferences:` URL scheme (System Settings deep links) is not a host and
does not trip the check.


**2026-09-17 — implemented.** `.github/workflows/release.yml` on `push: tags: v*`, permissions
`contents: write` only: setup-xcode (same pinned SHA as `ci.yml`) → *Tag matches VERSION* →
`make test` → `make trust zip` (one `sign` feeds both) → *Info.plist version equals the tag*
→ *archive round-trips* (`shasum -c`, `ditto -x`, `codesign --verify`) → `gh release create
--verify-tag --generate-notes`, with `--notes` prepended: a link to the run and the zip's
SHA-256, so the Release page itself carries what README › Verify a release asks for.
Hyphenated tags are `--prerelease`. No third-party release action; the runner's own token.
Makefile: `SIGN_IDENTITY ?= -` on `sign`, and `zip` (`ditto -c -k --keepParent --norsrc`,
`.sha256` written from inside `dist/` so `shasum -c` works in the download directory).
`ci.yml` runs `make zip` on every push. README rewritten in full; `docs/screenshot.png`.

**Verified.** Tag `v0.0.1-test` on a throwaway detached commit (VERSION bumped, never on
`main`) → run 35159444021 green on every step → pre-release with `tracklaude-v0.0.1-test.zip`
(294 946 B) and `.sha256` (93 B); body showed the run link and hash. `gh release download`
→ `shasum -a 256 -c` OK → `ditto -x -k` → `codesign --verify` valid, entitlements exactly the
three, `Info.plist` `0.0.1-test`. **Launch: the CI build crashed** — see Findings; fixed in the
commit after, and re-verified on the CI artefact (below). Release and tag deleted (`gh release delete --cleanup-tag`;
`git ls-remote --tags` and `gh release list` both empty). Locally the workflow's shell steps
were also run against `v0.1.0` (pass) and `v9.9.9` (tag guard fails, exit 1). Launch of the
downloaded copy: see below. CI on `main` (8258254) green with the new `zip` step.

**Decisions.**
- **Keychain prompt after every update: option (a), stay ad-hoc.** Documented in README ›
  Install › "The password prompt on first launch, and after every update" — two prompts,
  why, and why we accept it. (b) rejected: a signing key in CI secrets is the supply-chain
  property `research/usage4claude-study.md` faults in the original; the whole point of the
  project is not to ask for that trust. (c) noted in the README as the thing that would end
  both the prompt and the Gatekeeper step, if a paid account ever appears. No ADR needed
  for (a); ADR-0002 already carries the reasoning.
- The self-signed local cert is documented (Keychain Access › Certificate Assistant › Code
  Signing › Always Trust, then `make install SIGN_IDENTITY=name`). `make sign` was verified
  to pass a named identity through (a nonexistent name fails in `codesign` with "no identity
  found"); the owner currently has zero code-signing identities, so the cert itself is
  their step and the end-to-end was not exercised.
- Gatekeeper wording covers both macOS 14 (Control-click → Open) and 15+ (System Settings ›
  Privacy & Security › Open Anyway — Sequoia removed the Control-click override). From Apple's
  documentation; not exercised on this Mac because it means system dialogs on the owner's
  screen (see below).
- `--norsrc`: the only xattr a build carries is `com.apple.provenance`; the signature does
  not cover it and dropping it keeps `unzip` output free of `._*` files. Verified both ways.

**Findings.**
- **The CI-built binary crashed on launch; every local build ran.** `open`ing the
  downloaded `v0.0.1-test` app died in ~200 ms: SIGTRAP in `dispatch_assert_queue_fail`
  inside `AlertNotifier.requestPermission()`'s completion closure. In a `@MainActor` class
  that closure is inferred main-actor-isolated; the runner's Swift 6.0 / older SDK compiles
  a runtime queue assertion into it and `UNUserNotificationCenter` calls it on its own
  queue. Swift 6.2 locally emits no such check, so eight tickets of real-app verification
  never saw it. Fix: the three completion closures are explicitly `@Sendable`
  (nonisolated). `LoopbackSockets` (Network handlers) is a plain nonisolated class, so the
  sign-in path does not have the pattern. **Consequence for every later ticket: a launch
  or behaviour check on "the release" must use the CI-built artefact** — `ci.yml` now
  uploads `dist/tracklaude-v*.zip*` (7-day retention) on every push; `gh run download
  <run-id>`. `make install` proves nothing about what ships.
  Re-verified on the artefact of the fix commit (cfc700a): launched via `open -n`, alive
  past both notification-center callbacks, `State: signedOut → polling`, one fetch, no
  crash report.
- **Never run a second build against the owner's Keychain item.** The test copy read the
  shared credential (owner clicked Allow), refreshed, and the rotated refresh token left
  the installed app `stale(sessionExpired)` 22 s later — the rotation race from ADR-0001,
  now seen first-hand. For launch checks of a CI build, Deny the Keychain prompt (the app
  then shows `⚠ sign in`, which is proof enough), or test in a separate macOS user.
- **The usage endpoint budget is shared with something else on this account.** The app
  429'd at 10-minute spacing, one request each (backoff #3 → #6 over 30 min, `Retry-After:
  0` every time), and again the moment the popover opened after recovery. Nothing on this
  Mac visibly polls the endpoint (no statusline script, no other tracker running). Ticket 12
  should not treat a 429 during its end-to-end as an app defect without checking this first.
- **Popover screenshot mechanics.** AX cannot open the popover but a CGEvent HID click can
  (memory updated). The owner asked to be asked rather than have their screen driven —
  respect that; for any future screenshot, ask them for `⌘⇧4`+`Space` window capture.
- **Popover footer truncates** `Updated 42 s a…` at the default width — out of scope here,
  spawned as a separate task.
- The bundle has no icon yet; the pipeline does not freeze one (Info.plist has no
  `CFBundleIconFile`). The owner's logo ask is still open — raise before 12.
