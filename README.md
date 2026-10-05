<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/readme/lockup-dark.svg">
  <img src="docs/readme/lockup-light.svg" width="380" alt="tracklaude">
</picture>

### Your Claude usage limits, live in the Mac menu bar.

Signs in through Anthropic's own login page and talks to Anthropic, nobody else.<br>
Open source, sandboxed, and it never updates itself behind your back.

[![Latest release](https://img.shields.io/github/v/release/adios-404/tracklaude?label=release&labelColor=1A2B4D&color=2D4878)](https://github.com/adios-404/tracklaude/releases/latest)
[![macOS 14 or later on Apple silicon](https://img.shields.io/badge/macOS_14%2B-Apple_silicon-2D4878?labelColor=1A2B4D&logo=apple&logoColor=white)](#install)
[![Tests and trust checks](https://img.shields.io/github/actions/workflow/status/adios-404/tracklaude/ci.yml?branch=main&label=tests%20%2B%20trust%20checks&labelColor=1A2B4D)](https://github.com/adios-404/tracklaude/actions/workflows/ci.yml)
[![MIT license](https://img.shields.io/github/license/adios-404/tracklaude?labelColor=1A2B4D&color=2D4878)](LICENSE)

<br>

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/readme/hero-dark.png">
  <img src="docs/readme/hero-light.png" width="832" alt="The macOS menu bar with tracklaude's item reading 42% · 2h14m, its popover open below: the 5-hour window at 42 percent resetting in 2h14m, the 7-day window at 63 percent and the Fable window at 18 percent, each with a bar and its reset time; a Used / Remaining switch; Launch at Login and Alerts checkboxes; and Refresh, Sign out and Quit buttons.">
</picture>

<sub>Drawn from the app's own views with a sample reading. <a href="Scripts/readme-art">How</a>.</sub>

</div>

tracklaude exists because the alternative was a self-signed, self-updating binary that asked
for a full claude.ai session cookie. It asks for less, does less, and is built in public so
you can check both claims: everything below that says the app never does something is either
enforced by a check that runs on every push or points at the source lines you can read.

## What it shows

<dl>
<dt><picture><source media="(prefers-color-scheme: dark)" srcset="docs/readme/state-live-dark.png"><img src="docs/readme/state-live-light.png" width="250" alt="42% · 2h14m"></picture></dt>
<dd>The 5-hour window is 42 % used and resets in 2 h 14 min.</dd>
<dt><picture><source media="(prefers-color-scheme: dark)" srcset="docs/readme/state-stale-dark.png"><img src="docs/readme/state-stale-light.png" width="250" alt="42% · 2h14m ⚠ offline, dimmed"></picture></dt>
<dd>The last good reading, dimmed, because the latest check failed. The word says why: <code>offline</code>, <code>limited</code>, <code>expired</code> or <code>error</code>.</dd>
<dt><picture><source media="(prefers-color-scheme: dark)" srcset="docs/readme/state-nowindow-dark.png"><img src="docs/readme/state-nowindow-light.png" width="250" alt="—"></picture></dt>
<dd>Anthropic reports no active 5-hour window. An honest blank, not a made-up 0 %.</dd>
<dt><picture><source media="(prefers-color-scheme: dark)" srcset="docs/readme/state-signedout-dark.png"><img src="docs/readme/state-signedout-light.png" width="250" alt="⚠ sign in"></picture></dt>
<dd>Not signed in yet.</dd>
</dl>

- **Popover:** every window Anthropic reports (5-hour, 7-day, and per-model 7-day windows
  when they exist), each with a bar, the percentage, and when it resets, both as a countdown
  and as a time in your locale. Bars turn orange at 80 % and red at 90 %. A Used ↔ Remaining
  switch flips every number, the menu bar's included. When something is wrong, a banner
  says what (not signed in, offline, rate-limited, session expired) and offers the fix.
- **Alerts:** a notification the first time any window crosses 80 %, 90 % and 100 % in a
  cycle, and one when the 5-hour window resets after it had reached 80 %. Off with one
  click.
- **Footer:** how old the reading is, Refresh, Sign out, Quit. Launch at Login and Alerts
  are the two checkboxes above it.

<details>
<summary><b>How often it checks</b></summary>

<br>

Every 30 s while your Mac is awake. It pauses during sleep and checks again on wake.
Opening the popover shows the last reading without asking again; Refresh asks.

Anthropic sometimes refuses usage checks with 429 ("too many requests"). Its budget of
about 20–25 checks per 10 minutes is per account and shared with anything else that asks,
and refusals also come when this app has barely asked at all. tracklaude then retries after
1 minute and every 2 minutes after that, and keeps to a 2-minute pace until 30 minutes pass
without another refusal. The last reading stays on screen as it was; `⚠ limited` appears
only once that reading is 10 minutes old.

</details>

## Install

Needs an Apple silicon Mac (M1 or later) and macOS 14 or later.

```bash
brew install adios-404/tap/tracklaude
```

Or download `tracklaude-vX.Y.Z.zip` from the [latest release](https://github.com/adios-404/tracklaude/releases/latest)
and [follow these steps](#from-the-release-zip). Then open tracklaude, click its item in the
menu bar and choose **Sign in**. Your browser opens Anthropic's own login page; once you
approve, it lands on a one-line page served by the app on `localhost`, and you can close
the tab. Nothing is pasted anywhere.

> [!IMPORTANT]
> **macOS blocks the first launch, by design.** Releases are ad-hoc signed and not notarized
> ([why](#why-there-is-no-notarization)), so the first time you open tracklaude:
>
> - **macOS 15 and later:** open it once and dismiss the warning, then go to **System
>   Settings → Privacy & Security**, scroll to the note that tracklaude was blocked, and
>   click **Open Anyway**.
> - **macOS 14:** Control-click `tracklaude.app` in Applications → **Open** → **Open**.
>
> After an update, the new version's first launch asks for your login password **twice**.
> That is the Keychain, not the app ([why](#the-password-prompt-after-every-update)). An
> update may also repeat the step above. Neither comes back for the same version, and
> nothing is wrong with your download: you can [check that yourself](#verify-a-release).

### With Homebrew

Homebrew refuses the download unless it matches the SHA-256 in the cask, which the release
workflow copies from the Release's own `.sha256` file. It also marks the app as downloaded,
exactly like a browser does, and current Homebrew has no option to skip that, so the
first-launch step above applies. Update with `brew upgrade`.

### From the Release zip

1. Download `tracklaude-vX.Y.Z.zip` and `tracklaude-vX.Y.Z.zip.sha256` from the
   [latest Release](https://github.com/adios-404/tracklaude/releases/latest).
2. Check that the download is what CI built: see [Verify a release](#verify-a-release).
3. Unzip, and move `tracklaude.app` to `/Applications`.
4. Open it, and allow it as described above.
5. Click the menu-bar item and **Sign in**.

The macOS 15+ path was walked through on macOS 26 with a Homebrew install of v0.1.0 on
2026-10-03: a fresh install was blocked, the upgrade from 0.1.0 to 1.0.0 was not. The macOS
14 path is Apple's documented one and has not been tried here. Say so in an issue if the
wording is off.

### The password prompt after every update

On the first launch of every new version, if you are signed in, macOS asks for your login
password twice. Enter it both times (or click *Always Allow*). The same build never asks
again; a first sign-in does not ask at all.

<details>
<summary><b>Why it happens, and why the project accepts it</b></summary>

<br>

Releases are ad-hoc signed, which means each build has a different code hash, and the
Keychain item holding your credential is bound to the hash that created it. The first prompt
lets the new build read the item; the second adds the new build to the item's access list.
*Always Allow* does not carry over to the next version. A first sign-in does not ask because
the build that creates the item is already on its list. (Counted from the system log on
2026-10-03: two prompts on the first launch of 0.1.0 and again of 1.0.0 with an existing
sign-in, none for a fresh install of 1.0.1 through sign-in, Sign out and sign-in again.)

The alternative, signing every release with a private key held in CI, would give the app a
stable identity at the price of asking you to trust that key forever, which is the property
this project set out to avoid. If a paid Apple Developer account ever appears, notarized
releases would end both this prompt and the first-launch step.

</details>

## What it talks to

Exactly three hosts, all Anthropic's, plus loopback during sign-in. Nothing else, ever.

| Host | When | Why |
|---|---|---|
| `claude.ai` | Sign-in | Opens `https://claude.ai/oauth/authorize` in your browser (OAuth 2.0 with PKCE). The app itself never connects here; your browser does. |
| `console.anthropic.com` | Sign-in, token refresh | `POST /v1/oauth/token` to exchange the sign-in code for tokens, and later to refresh them when the access token expires. |
| `api.anthropic.com` | Every check | `GET /api/oauth/usage` with `Authorization: Bearer <access token>` and `anthropic-beta: oauth-2025-04-20`. Those are the only headers the app adds (macOS's `URLSession` adds its usual `User-Agent` and `Accept` ones): no browser-impersonating headers, no analytics. |
| `localhost` | Sign-in only | A listener on `127.0.0.1` and `::1`, port 1456 or 1458, that receives the browser's OAuth callback, checks the `state` value, and shuts down. It is bound to the loopback interface, not to your network. |

There is no update check, no crash reporter, no telemetry endpoint, no CDN. CI enforces this
with [`Scripts/check-hostnames.sh`](Scripts/check-hostnames.sh): every URL host, IPv4
literal and dotted name found in the built binary *and* in `Sources/` must be one of
`claude.ai`, `console.anthropic.com`, `api.anthropic.com`, `localhost`, `127.0.0.1`, or the
build fails.

What that check cannot see: a host assembled at runtime from pieces, and names under TLDs
the extractor ignores because they double as ordinary words (`.app`, `.sh`, `.so`, `.it`,
`.in`). It catches the honest mistake of a new literal; it is not a substitute for reading
the source, which is short. Start at
[`OAuthConfig.swift`](Sources/TracklaudeCore/OAuth/OAuthConfig.swift) and
[`UsageFetch.swift`](Sources/TracklaudeCore/Usage/UsageFetch.swift).

## What it holds

- **A narrow OAuth refresh token** (prefix `sk-ant-ort01-`, scope `user:profile`), in its
  own macOS Keychain item (`com.adios404.tracklaude` / `credential`). Never a claude.ai
  session cookie, never anything that can read or send your conversations. Access tokens
  live in memory only. **Sign out** deletes the Keychain item. Decision and trade-offs:
  [ADR-0001](docs/adr/0001-own-oauth-credential.md).
- **Nothing of Claude Code's.** Claude Code keeps its own Keychain item; tracklaude reads
  and writes only its own.
- **Three preferences** in UserDefaults, none secret: alerts on/off, used/remaining, and a
  mirror of the Launch-at-Login state. Launch at Login itself is a standard macOS login item
  that you can also see and remove in *System Settings → General → Login Items*.
- **No files.** The app writes no log files, caches, or history. Its only output is the
  unified system log
  (`/usr/bin/log show --predicate 'subsystem == "com.adios404.tracklaude"'`; the full path
  because zsh has a `log` of its own), and every line it writes there passes through a
  redactor that strips `sk-ant-…` tokens, `Bearer` values and JSON token fields: see
  [`LogRedactor.swift`](Sources/TracklaudeCore/Logging/LogRedactor.swift) and its tests.
  Log lines are deliberately `.public` so that `log show` is readable when you need to
  debug; the redactor is the only thing between your credential and that log, which is why
  it is tested and why CI refuses any other logging call
  ([`Scripts/check-log-redaction.sh`](Scripts/check-log-redaction.sh)).

## Trust

### No auto-update, on purpose

tracklaude has no updater and no version check. You update by downloading the next Release
(or running `brew upgrade`). A self-updating app means every future release, signed by one
person's key, can silently replace the code you audited; without notarization there is no
backstop. Removing the updater removes that dependency: the build you verified is the build
that runs, until you choose otherwise. Reasoning: [ADR-0002](docs/adr/0002-no-auto-update.md).

### Why there is no notarization

Notarization requires a paid Apple Developer account and a Developer ID certificate. This
project has neither, and rather than sign releases with a self-made certificate whose
private key sits in CI, it ships ad-hoc signed builds and asks you to verify them against
the public CI run instead. That is the trade: one first-launch click and a Keychain prompt
per update, in exchange for no key you have to trust.

### Sandbox

The app runs in the macOS App Sandbox with exactly three entitlements: `app-sandbox`,
`network.client` (HTTPS to the hosts above) and `network.server` (the loopback listener
during sign-in). No file access, no camera, no contacts, no Keychain access groups. The
source of truth is [`Packaging/tracklaude.entitlements`](Packaging/tracklaude.entitlements);
on every push CI reads the entitlements actually embedded in the signed bundle and fails
unless they are exactly those three
([`Scripts/check-entitlements.sh`](Scripts/check-entitlements.sh)).

### What's enforced vs. what needs your eyes

Enforced by `make trust`, which runs in CI on every push and in the release job before
anything is published:

- every log line is redacted, and no other logging call (nor any of the common file-writing
  calls: `print`, `NSLog`, `FileHandle`, `.write(to:)`) exists;
- the binary and source name no host outside the five listed above;
- the signed app carries exactly the three entitlements.

Not enforced, and worth a look if you are deciding whether to trust it: that the OAuth scope
requested really is `user:profile` (`OAuthConfig.swift`), that the usage request carries
nothing beyond the two headers (`UsageFetch.swift`), and that the loopback server binds to
loopback only (`Sources/tracklaude/Adapters/LoopbackCallbackServer.swift`).

One open question, stated in ADR-0001: the app signs in with the public OAuth client id that
Claude Code ships with. Whether Anthropic tolerates third-party use of it is not documented.
If sign-in ever fails with `invalid_client`, that is why.

## Verify a release

Every Release is built by [`.github/workflows/release.yml`](.github/workflows/release.yml)
from the tagged commit on a GitHub-hosted runner, after the full test suite and the trust
checks pass. The Release body links that run and repeats the zip's SHA-256. To check that
your download is that build:

```bash
cd ~/Downloads
shasum -a 256 -c tracklaude-vX.Y.Z.zip.sha256
```

Expected output: `tracklaude-vX.Y.Z.zip: OK`. The `.sha256` file is the one attached to
the Release; compare it with the hash printed in the linked workflow run's log if you want
to rule out a tampered Release page too. To go further, build from source at the same
tag and compare behaviour. The zips will differ (the ad-hoc signature is not reproducible
across machines, and your toolchain will not be the runner's), but the source is the same
tagged commit, and the Release body names it.

The version inside the app (`Info.plist`) always equals the tag; the release job refuses
to publish otherwise.

## Questions

<details>
<summary><b>Does it work on Intel Macs?</b></summary>

<br>

Not the releases: they are built for Apple silicon only. Building from source on an Intel
Mac may work, since `make` builds for the Mac it runs on, but nobody has tried it.

</details>

<details>
<summary><b>Will it sign me out of Claude Code?</b></summary>

<br>

No. tracklaude signs in on its own and keeps its own token in its own Keychain item. It
never reads or writes Claude Code's, so it cannot disturb that sign-in. Why it was built
that way: [ADR-0001](docs/adr/0001-own-oauth-credential.md).

</details>

<details>
<summary><b>Is Anthropic fine with this?</b></summary>

<br>

Not known, and worth knowing before you install. tracklaude signs in with the public OAuth
client id that Claude Code ships with, and Anthropic has not said whether other apps may use
it. If that changes, sign-in fails with `invalid_client`; nothing else about your account
is touched.

</details>

<details>
<summary><b>Does checking use up my limits?</b></summary>

<br>

No. A check asks Anthropic for your usage numbers; it never sends anything to a model.
Checks have a small budget of their own (about 20–25 per 10 minutes per account), which is
why the app checks every 30 s and backs off when Anthropic refuses.

</details>

<details>
<summary><b>Can it show more than one account?</b></summary>

<br>

No. One account at a time, by design.

</details>

<details>
<summary><b>Notifications show a blank icon</b></summary>

<br>

Versions before 1.0.5 had no icon Notification Center could read on macOS 26 and later, and
macOS keeps the blank one it saved. After updating, clear macOS's icon cache once (asks for
your password; the Dock flickers while it rebuilds):

```bash
sudo rm -rf /Library/Caches/com.apple.iconservices.store "$(getconf DARWIN_USER_CACHE_DIR)com.apple.iconservices" && sudo killall iconservicesd iconservicesagent; killall Dock NotificationCenter
```

</details>

<details>
<summary><b>How do I remove it completely?</b></summary>

<br>

Choose **Sign out** first: that deletes its Keychain item. Then quit it and run
`brew uninstall --zap tracklaude`, or drag it from Applications to the Trash. If you skipped
Sign out, delete the `com.adios404.tracklaude` item in Keychain Access.

</details>

## Build from source

Requires macOS 14+ and the Xcode Command Line Tools (`xcode-select --install`). Xcode
itself is not needed.

```bash
make install   # build (release), bundle, ad-hoc sign, copy to /Applications
open /Applications/tracklaude.app
```

Other targets: `make build`, `make test`, `make bundle`, `make sign`, `make trust`,
`make zip`, `make run`, `make clean`, `make icon`, `make assets`, `make readme-art`.

The icon ships twice: `Packaging/AppIcon.icns`, and `Packaging/Assets.car`, the asset
catalog Notification Center needs from macOS 26 (without it every banner shows a blank
icon). Both are committed. `make assets` rebuilds the catalog but needs Xcode's `actool`;
without Xcode, run the **Compile Assets.car** workflow on GitHub after `make icon` and
commit its artefact.

### Tests

```bash
make test
```

With only the Command Line Tools installed, bare `swift test` does not run the suite:
SwiftPM cannot find Swift Testing's framework directory without Xcode, so depending on the
toolchain it either fails with `no such module 'Testing'` or builds and silently runs
**zero** tests. `make test` passes the missing search path; see the comment in the
`Makefile`. The suite runs offline and never touches your Keychain or your usage.

### Stop the Keychain prompt during development

Every rebuild is a new ad-hoc code hash, so every rebuild asks for your password twice (see
[above](#the-password-prompt-after-every-update)). To give your local builds a stable
identity, create a self-signed code-signing certificate once and sign with it.

<details>
<summary><b>The four steps</b></summary>

<br>

1. Open **Keychain Access** → menu **Keychain Access → Certificate Assistant → Create a
   Certificate…**
2. Name: `tracklaude-dev` (anything you like). Identity Type: **Self Signed Root**.
   Certificate Type: **Code Signing**. Create.
3. In Keychain Access, find the new certificate under *My Certificates*, open it, expand
   **Trust**, and set *Code Signing* to **Always Trust**.
4. Sign with it:

   ```bash
   make install SIGN_IDENTITY=tracklaude-dev
   ```

`SIGN_IDENTITY` defaults to `-` (ad-hoc), which is what releases use. The certificate lives
only on your machine and only affects builds you make there. The Makefile side is verified;
the Keychain Access steps are the standard recipe and have not been walked through here.

</details>

### Cutting a release (maintainers)

Set `VERSION` to the new number, commit, tag and push:

```bash
git tag v1.0.4 && git push origin v1.0.4
```

<details>
<summary><b>What the release workflow does</b></summary>

<br>

It tests, signs, runs the trust checks, zips, hashes, and publishes the Release with
generated notes. A tag that does not match `VERSION` fails the job. Tags with a suffix
(`v1.0.0-rc1`) are published as pre-releases.

For a plain `vX.Y.Z` tag the workflow then opens a pull request on
[adios-404/homebrew-tap](https://github.com/adios-404/homebrew-tap) bumping the cask's
version and hash; that repository's CI audits it, and merging it is what `brew upgrade`
sees. Pre-releases never reach the tap. The job needs the `TAP_GITHUB_TOKEN` repository
secret: a fine-grained token for the tap repository only, with Contents and Pull requests
read/write. `Scripts/setup-tap-token.sh` walks through creating it and stores it (run it
again when the token expires).

</details>

## Reading further

- [`CONTEXT.md`](CONTEXT.md): the vocabulary (Window, Utilization, Credential, Snapshot…).
- [ADR-0001: the app holds its own narrow-scope OAuth refresh token](docs/adr/0001-own-oauth-credential.md)
- [ADR-0002: no auto-update mechanism](docs/adr/0002-no-auto-update.md)
- [`research/usage4claude-study.md`](research/usage4claude-study.md): the primary-source
  study of Usage4Claude v3.4.1 that this app was designed against: its signing, network
  surface, token handling and updater.
- [Security policy](.github/SECURITY.md) and [contributing guide](.github/CONTRIBUTING.md).

## License

MIT. See [`LICENSE`](LICENSE).
