# 01: Walking skeleton

**What to build:** `make install` produces a sandboxed, ad-hoc-signed `tracklaude.app` in `/Applications` from SwiftPM alone (Xcode Command Line Tools only, no Xcode). It appears in the menu bar with no Dock icon, shows `—`, and its popover contains only Quit. The package has two targets — `TracklaudeCore` (logic, no AppKit/SwiftUI) and the `tracklaude` executable — and `swift test` runs one trivial core test. GitHub Actions builds and tests on every push to the private repo.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [ ] `swift build` and `swift test` succeed with only Command Line Tools installed
- [ ] `make bundle` assembles an `.app` with Info.plist: bundle id `com.adios404.tracklaude`, `LSUIElement` true, `LSMinimumSystemVersion` 14.0, CFBundleShortVersionString from a single VERSION source
- [ ] `make sign` ad-hoc signs with entitlements: app-sandbox, network.client, network.server — nothing else
- [ ] `make install` copies to `/Applications`; launching shows `—` in the menu bar, no Dock icon, popover with Quit that quits
- [ ] `codesign -d --entitlements :-` on the installed app shows exactly the three entitlements
- [ ] CI workflow runs build + test on a macOS 14 runner and is green
- [ ] MIT LICENSE and a stub README exist
