# tracklaude

A macOS menu-bar app that shows how much of your Claude rate limits you've used and when
they reset. Open source, sandboxed, no auto-updater, talks only to Anthropic.

**Status: walking skeleton.** It shows `—` in the menu bar and a popover with Quit.
Sign-in and live usage are next.

## Build and run

Requires macOS 14+ and the Xcode Command Line Tools (`xcode-select --install`). Xcode itself
is not needed.

```bash
make install   # build (release), bundle, ad-hoc sign, copy to /Applications
open /Applications/tracklaude.app
```

Other targets: `make build`, `make test`, `make bundle`, `make sign`, `make run`, `make clean`.

### Tests

```bash
make test
```

With only Command Line Tools installed, bare `swift test` builds successfully but silently
runs **zero** tests — SwiftPM can't find Swift Testing's framework directory without Xcode.
`make test` passes the missing search path. See the comment in the `Makefile`.

## Trust

See `CONTEXT.md` for vocabulary and `docs/adr/` for the decisions behind the design.

## License

MIT — see `LICENSE`.
