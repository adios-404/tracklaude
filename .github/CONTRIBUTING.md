# Contributing

tracklaude is small on purpose and has one maintainer. Open an issue before a large change,
and count any change to sign-in, the network or what the app stores as large: agreeing on
the approach first costs less than rewriting a pull request. Security problems go to
[private reporting](SECURITY.md), not to issues.

## Build and test

You need macOS 14 or later and the Command Line Tools (`xcode-select --install`), not Xcode.

```bash
make test    # the whole suite, offline; never touches your Keychain or your usage
make trust   # build, sign, and run the checks CI runs on every push
make run     # build, sign, replace /Applications/tracklaude.app, and launch it
```

Use `make test`, never bare `swift test`. With only the Command Line Tools, SwiftPM cannot
find Swift Testing, so bare `swift test` either stops with `no such module 'Testing'` or,
worse, builds and runs zero tests without saying so. `make test` adds the missing search
path; the [`Makefile`](../Makefile) comment above `CLT_FRAMEWORKS` explains it.

`make trust` enforces the README's promises with three scripts:

- [`check-log-redaction.sh`](../Scripts/check-log-redaction.sh): only `AppLog.swift` may
  log, so every line passes through `LogRedactor`, and nothing prints or writes a file.
- [`check-hostnames.sh`](../Scripts/check-hostnames.sh): the binary and `Sources/` name no
  host but `claude.ai`, `console.anthropic.com`, `api.anthropic.com`, `localhost`, `127.0.0.1`.
- [`check-entitlements.sh`](../Scripts/check-entitlements.sh): the signed app has exactly
  `app-sandbox`, `network.client` and `network.server`.

Once you are signed in, the first launch of every rebuild asks for your login password
twice: the Keychain item holding your sign-in is bound to the code hash of the build that
created it, and every ad-hoc build has a new one. To stop it, sign local builds with a
self-signed certificate
(README › [Stop the Keychain prompt during development](../README.md#stop-the-keychain-prompt-during-development)).

Tests cover `TracklaudeCore` only. Feed it a recorded response from
`Tests/TracklaudeCoreTests/Fixtures` or a hand-built Snapshot, and a fixed `now`; assert on
what the user would see.

## Rules CI enforces

- **`TracklaudeCore` is logic only.** It must not import AppKit, SwiftUI or Cocoa; UI and
  real I/O live in the `tracklaude` target. CI runs
  `! grep -rnE '^import (AppKit|SwiftUI|Cocoa)' Sources/TracklaudeCore`.
- **CI builds with Swift 6.0**, stricter than the newer toolchain you probably have. It
  rejects `await` inside `#expect(...)`, so hoist the value into a `let` first:

  ```swift
  let sent = await transport.sent
  #expect(sent.count == 1)
  ```

  If you change the `tracklaude` target, also launch the build CI uploads for your push
  (artifact `tracklaude-<commit>`): a Swift 6.0 build has crashed where a local one ran.

## Out of scope

Decided, not overlooked ([spec › Out of Scope](../.scratch/tracklaude-v1/spec.md#out-of-scope)).
Please don't send pull requests for these; to argue for one, open an issue.

- A second provider, such as Codex or OpenAI.
- Multiple accounts or organisations.
- Session-cookie auth, in-app web login, or reading Claude Code's credentials
  ([ADR-0001](../docs/adr/0001-own-oauth-credential.md)).
- Auto-update or version checks of any kind ([ADR-0002](../docs/adr/0002-no-auto-update.md)).
- Notarization or Developer ID signing (no paid Apple account; revisit if one appears).
- Usage history, charts, overage or extra-usage dollar tracking, diagnostics export.
- Localisation beyond English, icon options, colour themes; iOS, widgets, Shortcuts, CLI output.

## Commits

Conventional commits (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`) whose
message says why; the diff shows what. For example:
`fix: notification-center callbacks must not assume the main actor — CI-built app crashed on launch`.
