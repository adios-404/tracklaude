# 01: Walking skeleton

**What to build:** `make install` produces a sandboxed, ad-hoc-signed `tracklaude.app` in `/Applications` from SwiftPM alone (Xcode Command Line Tools only, no Xcode). It appears in the menu bar with no Dock icon, shows `—`, and its popover contains only Quit. The package has two targets — `TracklaudeCore` (logic, no AppKit/SwiftUI) and the `tracklaude` executable — and `swift test` runs one trivial core test. GitHub Actions builds and tests on every push to the private repo.

**Blocked by:** None (can start immediately)

**Status:** done (2026-09-16, commits 83ad8bb, f59f90d)

- [x] `swift build` and `swift test` succeed with only Command Line Tools installed
- [x] `make bundle` assembles an `.app` with Info.plist: bundle id `com.adios404.tracklaude`, `LSUIElement` true, `LSMinimumSystemVersion` 14.0, CFBundleShortVersionString from a single VERSION source
- [x] `make sign` ad-hoc signs with entitlements: app-sandbox, network.client, network.server — nothing else
- [x] `make install` copies to `/Applications`; launching shows `—` in the menu bar, no Dock icon, popover with Quit that quits
- [x] `codesign -d --entitlements :-` on the installed app shows exactly the three entitlements
- [x] CI workflow runs build + test on a macOS 14 runner and is green
- [x] MIT LICENSE and a stub README exist

## Comments

**2026-09-16 — implemented.** All boxes verified locally and on CI (run 35115911699, macos-14, Swift 6.0.3, 1 test ran).

Deviations and findings worth knowing:

- **Bare `swift test` under Command Line Tools silently runs zero tests.** SwiftPM derives the
  Swift Testing framework path from `xcrun --show-sdk-platform-path`, which fails on CLT, so the
  generated test runner's `canImport(Testing)` is false and `main()` returns without running
  anything — exit 0, no output. `make test` passes the search path and runs the suite. Documented
  in README and the Makefile. If this is unacceptable, the alternative is XCTest (spec's "Swift
  Testing" convention would change).
- **`Label` in `MenuBarExtra` collapses to icon-only** — the `—` didn't render until the label was
  an explicit `HStack { Image; Text }`. Spotted by the owner from the menu bar.
- **`open -a tracklaude` can launch the `dist/` copy** instead of `/Applications` once both are
  registered with LaunchServices; the Makefile uses the explicit path.
- The popover's Quit button could not be exercised through accessibility (SwiftUI status items
  ignore synthetic clicks); verified by the owner clicking it.
- No app icon yet (spec mentions one under `bundle`; this ticket's checklist doesn't). Ticket #10.
- Endpoint-freshness measurement and fixture recording mentioned in the spec's "Ticket #1" note
  belong to sign-in/readout (tickets 02/03), which is where a real fetch first exists.
