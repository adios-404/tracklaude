# Usage4Claude v3.4.1 — primary-source study

Date: 2026-09-16
Subject: `/Applications/Usage4Claude.app` (bundle id `xyz.fi5h.Usage4Claude`, CFBundleShortVersionString 3.4.1)
Purpose: inform a from-scratch clone; answer "what does this app do with my Claude session token?"
Method: read-only inspection of the installed bundle, the arm64 slice's strings, on-disk artifacts, the Keychain (metadata only), the public repo `f-is-h/Usage4Claude` at tag `v3.4.1`, and the locally installed Claude Code CLI as a first-party cross-check. The app was not run; no login was performed; no secret values were read or printed.

Legend: **VERIFIED** = directly observed by the cited command. **INFERRED** = deduced from verified facts. **UNKNOWN** = could not be established.

## TL;DR

- **Token flow is local-only, as far as the binary and source show.** Every hostname in the binary is Anthropic/OpenAI first-party, GitHub (repo/sponsors/appcast), ko-fi (link only), status pages, or `codex-reset.com` (a third-party JSON feed that is fetched *without* any credential and only for the Codex badge). No analytics, no crash reporter, no developer-owned server. (VERIFIED — section 4)
- **The session key is stored in the login Keychain** as one generic-password item, service `xyz.fi5h.Usage4Claude`, account `accounts`, whose value is a JSON array of accounts (each with `sessionKey`, `organizationId`, `organizationName`, `alias`, `createdAt`, `provider`). ACL decrypt access is bound to this app's code-signing requirement. (VERIFIED — section 3)
- **The binary is self-signed and not notarized.** Signing identity is a self-issued cert `CN=Usage4Claude-CodeSigning, C=JP, emailAddress=<developer email>`, no Team ID, and `spctl -a -vv` says `rejected`. Sparkle auto-update is enabled with EdDSA-signed appcast entries, so update integrity rests entirely on the developer's EdDSA private key and GitHub account, not on Apple notarization. (VERIFIED — sections 1, 7)
- **Three ways to authenticate Claude:** (a) paste the `sessionKey` cookie, (b) log in inside a WKWebView and let the app harvest the `sessionKey` cookie, (c) OAuth/PKCE in the system browser using Claude Code's public client id, with a loopback callback server on `localhost:1456`/`1458` — this is what the `network.server` entitlement is for. Path (b) also copies claude.ai cookies into the app's persistent WebKit cookie store on disk. (VERIFIED from source + strings — section 3)
- **API surface for a clone:** cookie path = `GET https://claude.ai/api/organizations`, `GET https://claude.ai/api/organizations/{uuid}/usage`, `GET .../{uuid}/overage_spend_limit` with `Cookie: sessionKey=...` plus browser-mimicking headers; OAuth path = `GET https://api.anthropic.com/api/oauth/usage` with `Authorization: Bearer <access_token>` and `anthropic-beta: oauth-2025-04-20`. Response shape in section 5. Polling: 60 s active, backing off to 180/300/600 s. (VERIFIED — sections 5, 9)

## 1. Bundle & signing

Command: `plutil -p /Applications/Usage4Claude.app/Contents/Info.plist` — VERIFIED:

| Key | Value |
|---|---|
| CFBundleIdentifier | `xyz.fi5h.Usage4Claude` |
| CFBundleShortVersionString / CFBundleVersion | `3.4.1` / `3.4.1` |
| LSMinimumSystemVersion | `13.0` |
| LSUIElement | `true` (menu-bar-only agent app, no Dock icon) |
| LSApplicationCategoryType | `public.app-category.utilities` |
| DTXcode / DTSDKName | `2660` / `macosx26.5` (built with Xcode 26.6 on macOS 26 build 25G83) |
| SUFeedURL | `https://raw.githubusercontent.com/f-is-h/Usage4Claude/main/appcast.xml` |
| SUPublicEDKey | `p0CSf0X2mD0Z74yU64g36hGMQKpRE5/GFpaoyhhr6aY=` |
| SUEnableAutomaticChecks | `true` |
| SUEnableInstallerLauncherService | `true` |
| NSAppTransportSecurity | **absent** (no ATS exceptions; default ATS applies) — `grep -c NSAppTransportSecurity Info.plist` → 0 |

Command: `codesign -dvvv Contents/MacOS/Usage4Claude` — VERIFIED:

- `Format=app bundle with Mach-O universal (x86_64 arm64)`
- `Authority=Usage4Claude-CodeSigning` (single authority, i.e. self-signed leaf, no Apple chain)
- `TeamIdentifier=not set`
- `Signed Time=4 Sep 2026 at 4:55:05 PM`
- `CDHash=8f9257159e5c9da15b7f6e6554ce6e5b5bf3bc4a`
- Designated requirement (`codesign -d -r-`): `identifier "xyz.fi5h.Usage4Claude" and certificate leaf = H"c01a25bc537aab3a91bae4528700b193c3d5c773"`

Command: `codesign -d --extract-certificates=… ; openssl x509 -inform DER -noout -subject -issuer -dates` — VERIFIED:

- subject = issuer = `CN=Usage4Claude-CodeSigning, C=JP, emailAddress=<developer email>` (self-issued), valid 2025-10-19 → 2035-10-17, SHA-256 fingerprint `E7:98:3A:E7:AC:45:82:19:4A:2C:E0:A8:CB:A0:05:AE:30:25:AA:B8:D2:0E:3D:2E:81:3A:3F:3F:20:48:D6:A0`.

Command: `spctl -a -vv /Applications/Usage4Claude.app` — VERIFIED: `rejected`, `origin=Usage4Claude-CodeSigning`. The app is **not notarized** and would not pass Gatekeeper without the user's right-click → Open override (the GitHub release notes instruct exactly that).

Command: `codesign -d --entitlements :- /Applications/Usage4Claude.app` — VERIFIED entitlements:

- `com.apple.security.app-sandbox` = true
- `com.apple.security.network.client` = true
- `com.apple.security.network.server` = true (see section 4 for what it is used for)
- `com.apple.security.files.user-selected.read-write` = true (INFERRED use: "Export Report" save panel for the diagnostic report; pbxproj has `ENABLE_USER_SELECTED_FILES = readwrite`)
- `com.apple.security.temporary-exception.mach-lookup.global-name` = [`xyz.fi5h.Usage4Claude-spks`, `xyz.fi5h.Usage4Claude-spki`] (standard Sparkle-in-sandbox pattern for its status/installer XPC services)

No hardened-runtime flags appear in `codesign -dvvv` output (`flags=0x0(none)`) — VERIFIED. Hardened runtime is not enabled.

Command: `otool -L Contents/MacOS/Usage4Claude` — VERIFIED linked frameworks (both slices identical): `@rpath/Sparkle.framework/Versions/B/Sparkle (current version 2.9.2)`, Foundation, AppKit, Combine, CoreFoundation, CoreGraphics, CryptoKit, Security, ServiceManagement, SwiftUI, UserNotifications, WebKit, libswiftNetwork, libswiftXPC (weak), plus the usual Swift runtime dylibs. No third-party dylibs other than Sparkle.

Command: `ls -la Contents/Frameworks Contents/Resources` — VERIFIED: `Frameworks/` contains only `Sparkle.framework`. `Resources/` contains `AppIcon.icns`, `Assets.car`, and `de|en|fr|ja|ko|zh-Hans|zh-Hant.lproj/Localizable.strings`. There is no `Contents/XPCServices` and no `Contents/Library` (LoginItems) directory.

Sparkle: `plutil -p Frameworks/Sparkle.framework/Versions/B/Resources/Info.plist` — VERIFIED `CFBundleShortVersionString 2.9.2`, `CFBundleVersion 2057`, `CFBundleIdentifier org.sparkle-project.Sparkle`. The framework ships `Autoupdate`, `Updater.app`, `XPCServices/Downloader.xpc` (`org.sparkle-project.DownloaderService`), `XPCServices/Installer.xpc` (`org.sparkle-project.InstallerLauncher`). All are re-signed with the same self-signed `Usage4Claude-CodeSigning` identity (`codesign -dvv` on each), and both XPC services have empty entitlement dictionaries.

## 2. Features

Sources: `iconv -f UTF-16LE -t UTF-8 Contents/Resources/en.lproj/Localizable.strings` (VERIFIED) and `strings -n 6` on the arm64 slice extracted with `lipo -thin arm64` (VERIFIED, 7,094 strings; file at `/private/tmp/claude-501/-Users-darthvader-Code-claudeusagetrackercustom/393a0fb4-e1d4-4526-8533-5489046d26b0/scratchpad/strings-arm64.txt`).

User-facing features (VERIFIED from Localizable.strings keys unless noted):

- **Providers:** Claude (claude.ai) and Codex/OpenAI (chatgpt.com). Codex is out of scope for the clone but its code is entangled (shared account store, refresh manager).
- **Limit types tracked:** `five_hour`, `seven_day`, `seven_day_opus` ("7D Opus Limit"), `seven_day_sonnet` ("7D Sonnet Limit"), `extra_usage` (dollar-based overage), plus new-style `limits[]` entries with `kind == "weekly_scoped"` and `scope.model.display_name` (source `ClaudeAPIResponseModels.swift`; the comment names "Fable" as an example model).
- **Menu-bar display:** modes `percentage_only`, `icon_only`, `both`, `no_display`; icon styles `color_translucent`, `color_with_background`, `monochrome`; icon sizes `small|medium|large` ("Compact/Standard/Prominent"); "Smart Display" (auto-show all limit types with data) vs "Custom Display" (pick limit types; optional "apply only to menu bar"); constraint "at least one circular limit must be selected"; colored themes only with ≤2 circular indicators; `showRemainingMode` toggle (show remaining vs used); loading animations `rainbow|dashed|pulse`.
- **Refresh:** `refresh.smart_mode` ("1 min when active, up to 10 min when idle") or `refresh.fixed_mode` with `1|3|5|10 minutes`. Manual refresh with cooldown ("Please wait a moment"). Refresh on wake from sleep and on popover open (strings "System woke from sleep; refreshing immediately", "Popover opened; switching from idle to active mode").
- **Reset verification:** after a limit's `resets_at` passes, re-fetch at +1 s, +10 s, +30 s (`codexResetVerify1..3`, "Claude reset verification +30s: refreshing").
- **Notifications:** single toggle `notificationsEnabled`; fires when any limit reaches **90%** or when usage resets (`NotificationThresholds.warning = 90.0`, `resetDrop = 30.0`, plus a `sevenDayEarlyWarning` constant — source `NotificationDecisionEngine.swift`). Uses `UNUserNotificationCenter` (selectors `userNotificationCenter:willPresentNotification:…` in strings).
- **Multi-account:** Claude and Codex account lists, alias per account, per-account org id, "Validate & Add", auto-create one account per organization when a session key belongs to multiple orgs (`account.multi_org_added`).
- **Auth UI:** welcome wizard; Settings → Authentication tab with "Sign in via Browser (Recommended)" / "Manual Input"; session-key format check "Session Key should be 20-500 characters"; hint "usually starts with sk-ant-sid".
- **Launch at login:** `SMAppService.mainApp.register()/unregister()` with status reflected from `SMAppService.mainApp.status` (source `LaunchAtLoginManager.swift`; ServiceManagement is linked).
- **Diagnostics:** "Test Connection", detailed report, "Export Report" (Markdown, redacted by `SensitiveDataRedactor` — regexes for `sessionKey=…`, JWTs, UUIDs are in strings), "Open Log Folder".
- **Logging:** rotating file log under the container at `…/Usage4Claude/logs/` (`AppLog.swift` line 170), capped; trace level (which is the only level that logs raw response bodies) is not written to disk in Release (`LogRetentionPolicy.shouldWriteToFile`). INFERRED: session key never reaches the log file because all messages pass through `SensitiveDataRedactor.redactLogMessage` (AppLog.swift line 266).
- **Languages:** en, ja, zh-Hans, zh-Hant, ko, fr, de. Appearance system/light/dark. 12h/24h time format.
- **Update:** Sparkle "Check for Updates" menu item; in-app "New Version Available" badge.
- **Menu links:** Claude status page, OpenAI status page, Buy Me A Coffee (ko-fi), GitHub Sponsor, About.
- **Keyboard shortcuts:** none found in strings or Localizable (UNKNOWN whether any exist beyond standard menu accelerators).
- **Codex reset announcement badge (Beta):** default **on** (`UserSettings.swift` line 922: `?? true`); polls `codex-reset.com` — see section 4.

UserDefaults keys (VERIFIED from `grep -oE 'forKey: "[A-Za-z_]+"' UserSettings.swift` cross-checked against binary strings): `customDisplayMenuBarOnly customDisplayTypes displayMode hasLaunched iconDisplayMode iconStyleMode isFirstLaunch language menuBarIconSize notificationsEnabled refreshInterval refreshMode showCodexResetAnnouncement timeFormatPreference currentAccountId currentCodexAccountId organizationIdMigrated multiAccountMigrated cachedOrganizations notifiedWarnings showRemainingMode` plus DEBUG-only keys (`debugModeEnabled`, `debugScenario`, `simulateUpdateAvailable`, …) which are **absent from the release binary** (`grep -cE 'UserDefaultsCredentialStorage|DEBUG_' strings-arm64.txt` → 0), confirming a Release build with the Keychain storage backend compiled in.

Note on `cachedOrganizations`: an org list (id, uuid, name, capabilities, created/updated) may be cached in UserDefaults; this contains no secret but does contain the org UUID and name. INFERRED from key name + `Organization` Codable keys; not observable on this machine (see section 3, TCC).

## 3. Token acquisition & storage

### How the token is acquired (VERIFIED from source at tag v3.4.1, cross-checked against binary strings)

1. **Manual paste** (`AuthSettingsView+AddAccount.swift`, Localizable `settings.auth.step1…6`): user copies the `sessionKey` cookie from DevTools and pastes it. Format check is length 20–500. The app then calls `GET https://claude.ai/api/organizations` to discover org UUID(s) and creates one `Account` per org.
2. **In-app browser login** (`WebLoginCoordinator.swift`): opens `https://claude.ai/login` in a `WKWebView` whose `websiteDataStore = .nonPersistent()` (line 69). A 1-second timer polls `httpCookieStore.getAllCookies` for a cookie named `sessionKey` on a `claude.ai` domain (lines 136–149). On detection it validates via `/api/organizations`, creates the account, and then **copies all claude.ai cookies into `WKWebsiteDataStore.default().httpCookieStore`** (`transferCookiesToDefaultStore`, lines 114–123; comment says it is "for Level 2 silent refresh", a mechanism that exists only for Codex — `CodexSilentRefreshCoordinator.swift` — so for Claude this copy is effectively vestigial). INFERRED consequence: after a browser login the `sessionKey` cookie also persists in the app container's WebKit cookie store on disk (`~/Library/Containers/xyz.fi5h.Usage4Claude/Data/Library/Cookies/` or `…/WebKit/`), in addition to the Keychain. Could not be confirmed on disk because of TCC (below).
3. **OAuth / PKCE in the system browser** (`ClaudeOAuthConfig.swift`, `ClaudeOAuthService.swift`, `ClaudeOAuthCoordinator.swift`): authorize at `https://claude.ai/oauth/authorize`, token at `https://console.anthropic.com/v1/oauth/token` (JSON body), `client_id = 9d1c250a-e61b-44d9-88ed-5944d1962f5e`, `scope = user:profile`, redirect `http://localhost:1456/callback` (fallback port 1458), manual fallback redirect `https://console.anthropic.com/oauth/code/callback` plus a "paste the localhost URL" fallback. The source comment says this reuses Claude Code's public client. **First-party cross-check VERIFIED:** the locally installed Claude Code CLI (`/Users/darthvader/.local/share/claude/versions/2.1.263`) contains the same client-id UUID (2 hits), `/api/oauth/profile`, `/api/oauth/usage`, `/oauth/authorize`, `/v1/oauth/token`, `oauth-2025-04-20`, and `user:profile`. The resulting credential stored by the app is the **refresh token** (prefix `sk-ant-ort01-`, `ProviderAuthPath.swift` line 11); access tokens are held only in memory by the `OAuthTokenCache` actor (`private var cachedAccessToken`, no UserDefaults/Keychain calls in that file).

Auth path selection at runtime: `ProviderAuthPath.forClaude(credential:)` — credential starting with `sk-ant-ort01-` → OAuth path (`api.anthropic.com/api/oauth/usage`), anything else → cookie path (`claude.ai/api/organizations/{id}/usage`). VERIFIED in source; binary strings confirm both URL sets are present.

### Where it is stored

Source (`KeychainManager.swift`, VERIFIED): Release builds use `SecItemAdd` with `kSecClassGenericPassword`, `kSecAttrService = Bundle.main.bundleIdentifier` (`xyz.fi5h.Usage4Claude`), `kSecAttrAccount = "accounts"` (Claude list) or `"accounts_codex"` (Codex list), value = UTF-8 JSON of `[Account]`. Legacy single-account keys `sessionKey` / `organizationId` are migrated then deleted (`organizationIdMigrated`, `multiAccountMigrated`). No `kSecAttrAccessible`, no `kSecUseDataProtectionKeychain`, no iCloud sync flag — i.e. a plain login-keychain item with a per-item ACL. Debug builds would write plaintext to UserDefaults under `DEBUG_*` keys, but that code is absent from the shipped binary (section 2).

On this machine — VERIFIED with `security find-generic-password -s xyz.fi5h.Usage4Claude` (no `-w`/`-g`; value not read) and `security dump-keychain -a` filtered to the item:

- keychain `/Users/darthvader/Library/Keychains/login.keychain-db`, class `genp`, `svce = "xyz.fi5h.Usage4Claude"`, `acct = "accounts"`, created/modified `2026-09-16 06:00:54Z`. Exactly one item; no `accounts_codex`, `sessionKey`, or `organizationId` items exist.
- ACL: decrypt/export authorized for exactly one application, `/Applications/Usage4Claude.app`, with requirement `identifier "xyz.fi5h.Usage4Claude" and certificate leaf = H"c01a25bc…"`; `partition_id` entry = `cdhash:8f9257159e5c9da15b7f6e6554ce6e5b5bf3bc4a`. INFERRED: because there is no Team ID, macOS partitions the item by the app's cdhash; any rebuilt/updated binary has a new cdhash, so after a Sparkle update the user is expected to see a Keychain "allow access" prompt (or the app silently fails to read and shows "Authentication not configured"). This is consistent with the v3.4.0 release title "Account Credential Fixes".

Container on disk: `ls -la ~/Library/Containers/xyz.fi5h.Usage4Claude/` — VERIFIED the container exists (`Data/` modified 2026-09-15). **`ls` of `Data/` and every subdirectory returned `Operation not permitted`** (TCC protects other apps' containers from this shell; the shell lacks Full Disk Access). `defaults read xyz.fi5h.Usage4Claude` → "Domain … not found" and `defaults export` → empty dict, for the same reason. Therefore: Preferences, Application Support, Caches, Cookies, HTTPStorages and logs inside the container are **UNKNOWN** on this machine. Nothing Usage4Claude-related exists outside the container (`ls ~/Library/Preferences | grep -i usage4claude` → none).

## 4. Network surface

Command: `grep -nE 'https?://|wss?://' strings-arm64.txt` — VERIFIED complete list of URLs in the arm64 slice:

| URL | Classification | Purpose (VERIFIED from source unless noted) |
|---|---|---|
| `https://claude.ai/api/organizations` and `…/api/organizations/` (+`/{uuid}/usage`, `/{uuid}/overage_spend_limit`) | Anthropic first-party | cookie-auth org discovery, usage, extra-usage |
| `https://claude.ai`, `https://claude.ai/settings/usage` | Anthropic first-party | `origin`/`referer` headers; "open in browser" link |
| `https://claude.ai/oauth/authorize` | Anthropic first-party | OAuth authorize |
| `https://console.anthropic.com/v1/oauth/token` | Anthropic first-party | OAuth code exchange + refresh |
| `https://api.anthropic.com/api/oauth/profile`, `…/api/oauth/usage` | Anthropic first-party | OAuth profile (email/org) and usage |
| `https://status.claude.com`, `https://status.openai.com/` | first-party status pages | opened in browser from menu |
| `https://chatgpt.com`, `https://chatgpt.com/api/auth/session`, `https://chatgpt.com/backend-api/wham/usage`, `https://auth.openai.com/oauth/authorize`, `…/oauth/token`, `https://api.openai.com/auth` | OpenAI first-party | Codex provider only |
| `https://codex-reset.com/api/forecast`, `…/api/timeline`, `https://codex-reset.com/` | **third-party** community site | Codex "reset announcement" badge; polled with a custom `User-Agent: … (+https://github.com/f-is-h/Usage4Claude)`, **no credentials attached** (`CodexResetAnnouncementService.swift` sets only User-Agent). Gated by `showCodexResetAnnouncement` (default true) and by `CodexAnnouncementFetchPolicy` (≥60 s between attempts, 30 min TTL when quiet, backoff 5→60 min on failure). |
| `https://raw.githubusercontent.com/f-is-h/Usage4Claude/main/appcast.xml` | Sparkle update feed (GitHub) | Info.plist `SUFeedURL` |
| `https://github.com/f-is-h/Usage4Claude/releases/download/…dmg` | Sparkle enclosure (GitHub) | from live appcast |
| `https://github.com/f-is-h`, `…/Usage4Claude`, `…/issues`, `…/blob/main/docs/README.*.md`, `https://github.com/sponsors/f-is-h?…` | developer's GitHub | About/help/sponsor links opened in browser |
| `https://ko-fi.com/1atte` | third-party donation page | menu link only |
| `http://localhost:` | loopback | OAuth callback redirect base |

**No** analytics, telemetry, crash-reporting, or developer-controlled hostname exists in the binary. `grep -nE '\.(com|ai|xyz|io|net|org|dev|app)…'` found nothing beyond the above (the `xyz` in `xyz.fi5h.Usage4Claude` is only the bundle id). VERIFIED.

**`com.apple.security.network.server`:** VERIFIED use is the OAuth loopback callback: `OAuthCallbackServer.swift` creates an `NWListener(using: NWParameters.tcp, on: port)` without `requiredLocalEndpoint` (comment: listen on both IPv4/IPv6 loopback so `localhost` resolving to `::1` works), serves a one-shot HTML "Signed in successfully"/"404 Not Found" page (both HTML bodies are in the binary strings), and stops. Ports: Claude 1456 → 1458; Codex 1455 → 1457 (Localizable `weblogin.codex_oauth_port_busy`). Bonjour/mDNS strings: none. INFERRED caveat: `NWListener` without `requiredLocalEndpoint` binds to all interfaces, not only loopback, so during the seconds a login is pending the port is reachable from the LAN; the handler only accepts `/callback` with a matching `state` (string "Claude OAuth state validation failed; rejecting the callback"), so the practical exposure is limited to a state-mismatch 404. The pbxproj sets `ENABLE_INCOMING_NETWORK_CONNECTIONS = NO`, but the shipped entitlements do include `network.server` via `Config/Usage4Claude.entitlements` — the entitlements file wins.

ATS: no `NSAppTransportSecurity` key (VERIFIED). All endpoints are HTTPS except the loopback callback (which is exempt from ATS as `localhost`).

## 5. Claude usage API surface

All VERIFIED from `ClaudeAPIService.swift`, `ClaudeAPIHeaderBuilder.swift`, `ClaudeAPIResponseModels.swift`, `ClaudeOAuthConfig.swift` at tag v3.4.1, with every URL, header name and JSON key also present in the binary strings.

### Cookie path (credential = `sessionKey` cookie value)

Requests (`GET`, `URLSession` with `timeoutIntervalForRequest = 30`, `timeoutIntervalForResource = 60`, `assumesHTTP3Capable = false`):

- `GET https://claude.ai/api/organizations` → `[Organization]` with keys `id` (Int), `uuid`, `name`, `created_at`, `updated_at`, `capabilities: [String]`.
- `GET https://claude.ai/api/organizations/{uuid}/usage` → `UsageResponse` (below).
- `GET https://claude.ai/api/organizations/{uuid}/overage_spend_limit` → `ExtraUsageResponse` (below); failure is non-fatal ("Extra Usage request failed; continuing with main usage data only").

Headers set on every cookie-path request (`ClaudeAPIHeaderBuilder.buildHeaders`, comment: "to bypass Cloudflare bot detection; must match a real browser"):

```
accept: */*
accept-language: <Locale.preferredLanguages, q-weighted>   (binary also carries "zh-CN,zh;q=0.9,en;q=0.8" for Codex)
content-type: application/json
anthropic-client-platform: web_claude_ai
anthropic-client-version: 1.0.0
user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36
origin: https://claude.ai
referer: https://claude.ai/settings/usage
sec-fetch-dest: empty
sec-fetch-mode: cors
sec-fetch-site: same-origin
Cookie: sessionKey=<value>
```

Status handling: HTML body containing `<!DOCTYPE html>`/`<html` → "Cloudflare challenge"; 401/403 → unauthorized; 429 → rate limited; JSON `{"type":…,"error":{"type":"permission_error"|"authentication_error","message":…}}` → session expired; HTTP 200 with every window null → "usage dashboard unavailable" (Free tier / Team without member dashboard).

`UsageResponse` schema (Codable):

```
{
  "five_hour":          { "utilization": <Double 0-100>, "resets_at": <ISO8601 with fractional seconds | null> } | null,
  "seven_day":          { same } | null,
  "seven_day_oauth_apps": { same } | null,        // present, unused by the app
  "seven_day_opus":     { same } | null,          // legacy per-model field
  "seven_day_sonnet":   { same } | null,          // legacy per-model field
  "limits": [                                     // newer unified array
    { "kind": "session"|"weekly_all"|"weekly_scoped"|…, "group": String?, "percent": Double?,
      "severity": String?, "resets_at": String?, "is_active": Bool?,
      "scope": { "model": { "id": String?, "display_name": String? }?, "surface": String? }? }
  ] | null,
  "member_dashboard_available": Bool | null
}
```

`resets_at` is parsed with `ISO8601DateFormatter` options `[.withInternetDateTime, .withFractionalSeconds]` and rounded to the nearest second. Per-model weekly entries are `limits[]` items whose `scope.model.display_name` is non-empty; the legacy `seven_day_opus`/`seven_day_sonnet` are treated as absent when `utilization == 0 && resets_at == nil`.

`ExtraUsageResponse` (`/overage_spend_limit`) schema:

```
{ "limit_type": String?, "is_enabled": Bool?, "monthly_limit": Int? (cents), "currency": String?,
  "used_credits": Double? (cents), "out_of_credits": Bool?,
  // legacy names still decoded:
  "type": String?, "monthly_credit_limit": Int?, "spend_limit_currency": String?,
  "spend_limit_amount_cents": Int?, "balance_cents": Int? }
```

Binary strings additionally contain keys not in the Claude models: `has_credits`, `unlimited`, `overage_limit_reached`, `balance`, `approx_local_messages`, `approx_cloud_messages`, `primary_window`, `secondary_window`, `limit_window_seconds`, `reset_after_seconds`, `plan_type`, `rate_limit`, `official_signal`, `teased_window`, `signal_percent`, `commitment`, `target_at`, `target_kind`, `start_at`, `end_at`, `official_window` — INFERRED these belong to the Codex `wham/usage` response and the `codex-reset.com` feed, not to Claude.

### OAuth path (credential = refresh token `sk-ant-ort01-…`)

- Refresh: `POST https://console.anthropic.com/v1/oauth/token`, `Content-Type: application/json`, body `{"grant_type":"refresh_token","refresh_token":…,"client_id":"9d1c250a-e61b-44d9-88ed-5944d1962f5e"}` → `{access_token, refresh_token?, expires_in}` (comment: `expires_in` typically 3600; refresh tokens rotate and the new value is written back to the Keychain account).
- Code exchange: same URL, body `{"grant_type":"authorization_code","code","state","redirect_uri","client_id","code_verifier"}`.
- Usage: `GET https://api.anthropic.com/api/oauth/usage` with `Authorization: Bearer <access_token>` and `anthropic-beta: oauth-2025-04-20`; the same `UsageResponse` model is decoded (the source logs `extra_usage` keys from this response; the cookie path gets extra usage from `/overage_spend_limit` instead). 401 → clear cached access token, refresh once, retry.
- Profile: `GET https://api.anthropic.com/api/oauth/profile` (same headers) → `{ "account": { "email", … }, "organization": { "uuid", "name" } }`.
- The Claude Code CLI on this machine additionally uses `/api/oauth/usage?at_wall=1&skip_spend=1` (VERIFIED by `strings` on the CLI binary) — a query variant the app does not use.

## 6. Public source

Commands: `gh search repos Usage4Claude`, `gh search code "xyz.fi5h.Usage4Claude"`, `gh repo view f-is-h/Usage4Claude`, `gh release list/view`, `gh api repos/f-is-h/Usage4Claude/git/trees/v3.4.1?recursive=1`, `gh api …/contents/<path>?ref=v3.4.1` — VERIFIED:

- Repo: `https://github.com/f-is-h/Usage4Claude`, created 2025-10-22, 393 stars, default branch `main`, not archived, last push 2026-09-07.
- **License: MIT** (`LICENSE` file, "Copyright (c) 2025-2026 f-is-h"; also `settings.about.license_value = "MIT License"` in the binary). MIT permits copying with attribution; a clean-room clone that does not copy code has no license obligation at all, and even direct reuse only requires keeping the copyright/permission notice.
- Latest release `v3.4.1` published 2026-09-04T11:26:02Z with asset `Usage4Claude-v3.4.1.dmg` (5,752,461 bytes, `sha256:5f4e62a1…68b8d`) and a `.sha256` sidecar. The installed app's version `3.4.1`, signing time 2026-09-04 16:55 (local), and the appcast `length="5752461"` for v3.4.1 are mutually consistent. The installed bundle's own hash could not be compared to the DMG because no v3.4.1 DMG is present locally; **INFERRED** (not proven) that the installed build is the GitHub release. Provenance of the earlier download is VERIFIED: `~/Downloads/Usage4Claude-v3.3.0.dmg` sha256 `5d12b050…eab834` matches the GitHub v3.3.0 asset digest exactly.
- Tag `v3.4.1` = tag object `b80e342e…`. Source tree contains the exact file names seen in binary strings (`Usage4Claude/KeychainManager.swift`, `ClaudeAPIHeaderBuilder.swift`, `ClaudeOAuthCoordinator.swift`, `OAuthCallbackServer.swift`, `SensitiveDataRedactor.swift`, …), and every URL, header, JSON key, Localizable key, and UserDefaults key checked in sections 2–5 matches between source and binary. The `Config/Info.plist` in the repo carries the same `SUFeedURL` and `SUPublicEDKey` as the installed app, and `scripts/build.sh` + `project.pbxproj` specify `CODE_SIGN_IDENTITY = "Usage4Claude-CodeSigning"`, `DEVELOPMENT_TEAM = ""`, `MACOSX_DEPLOYMENT_TARGET = 13.0` — matching the observed signature. **No discrepancy between shipped binary and tagged source was found.** (Reproducible-build equality was not attempted.)
- The repo has a SwiftPM test target (`Tests/Usage4ClaudeCoreTests/…`, e.g. `UsageResponseTests`, `SensitiveDataRedactorTests`, `OAuthTokenCacheTests`) and a `CLAUDE.md`; most comments are Chinese; several files are headed "Created by Claude Code".
- Not on the Mac App Store (INFERRED from self-signing and DMG distribution; `gh` shows GitHub releases only).
- Related forks found: `arcanii/Usage4Claude-Arcanii`, `quangyendn/UsagePaceCC`, `AurelianSteiner/Max-Monitor` (all MIT).

## 7. Auto-update (Sparkle 2.9.2)

VERIFIED:

- `SUFeedURL = https://raw.githubusercontent.com/f-is-h/Usage4Claude/main/appcast.xml`; `SUPublicEDKey` present (Ed25519); `SUEnableAutomaticChecks = true`; `SUEnableInstallerLauncherService = true`; Sparkle's `Installer.xpc` and `Downloader.xpc` are bundled; entitlements carry the `-spks`/`-spki` mach-lookup exceptions. `SPUStandardUpdaterController` symbol is in the binary.
- Live appcast (`curl https://raw.githubusercontent.com/f-is-h/Usage4Claude/main/appcast.xml`, HTTP 200, 12,667 bytes): entries v3.4.1, v3.4.0, v3.3.0, v3.2.2, v3.2.1, v3.2.0; every enclosure has `sparkle:edSignature="…"` and `length` (6 edSignatures, 0 DSA); enclosure URLs point at `github.com/f-is-h/Usage4Claude/releases/download/…`; `sparkle:minimumSystemVersion` 13.0. The v3.2.0 entry has `sparkle:version` = `1` (a build-number quirk, harmless).
- `scripts/build.sh` lines 386–402: DMGs are signed with `sign_update` using an EdDSA private key kept in the developer's login Keychain.

Assessment (INFERRED from the verified configuration and Sparkle 2's documented verification model, which was not independently re-derived from the framework binary):

- Because `SUPublicEDKey` is set, Sparkle 2 will refuse an update whose DMG does not verify against that key. A compromised GitHub account or `main` branch alone is therefore insufficient; the attacker also needs the developer's EdDSA private key (or must also be able to ship a new binary with a new key, which the running app would reject).
- What is *missing* compared with a conventional setup: no Apple Developer ID, no notarization, no hardened runtime, no Team ID. Consequently (a) Gatekeeper provides no independent check on updates, (b) the Keychain partition is by cdhash so each update changes the identity the Keychain item was granted to, and (c) all trust reduces to one person's EdDSA key + self-signed cert. Sparkle additionally requires the new bundle's code signature to be valid and, by default, to match the old bundle's signing identity; with a self-signed cert both old and new are signed by the same self-issued leaf, so that check passes as long as the developer keeps the cert.
- Threat model answer: **a compromised appcast alone cannot push arbitrary code** (EdDSA gate). **A compromised developer machine/key can**, and the resulting update would run inside the same sandbox with Keychain access to the stored session key(s). That is the standard Sparkle risk profile for any self-updating app; what makes it slightly worse here is the absence of notarization as a second, Apple-controlled gate.

## 8. Risk assessment (session-token misuse)

| # | Finding | Severity for "will my token be misused?" | Status |
|---|---|---|---|
| 1 | Token is sent only to `claude.ai` / `api.anthropic.com` / `console.anthropic.com`; no other host receives it. Binary has zero analytics/telemetry/developer endpoints. | **Low** (this is the core question, and the answer is clean) | VERIFIED (strings + source) |
| 2 | Token at rest is in the login Keychain with an app-specific ACL, not in plaintext prefs. | Low | VERIFIED |
| 3 | After *browser-login* (path b), claude.ai cookies incl. `sessionKey` are also copied into the app's persistent WebKit cookie store on disk inside the sandbox container. Redundant copy; any process with Full Disk Access or the user's account could read it. Manual-paste and OAuth paths do not do this. | Low–Medium (local-only exposure, mitigated by sandbox container + FileVault) | VERIFIED in source; on-disk presence UNKNOWN (TCC) |
| 4 | App is self-signed, not notarized, no hardened runtime, no Team ID. Users must bypass Gatekeeper to install. There is no Apple-side identity behind the developer beyond an iCloud email in the cert. | Medium (supply-chain / accountability, not runtime behavior) | VERIFIED |
| 5 | Auto-update enabled; EdDSA-signed appcast on GitHub; developer key compromise ⇒ arbitrary code with Keychain access to the token. | Medium (inherent to any self-updating app; no notarization backstop) | VERIFIED config; impact INFERRED |
| 6 | OAuth path stores a long-lived `sk-ant-ort01-` refresh token minted under Claude Code's public client id with scope `user:profile` — a narrower capability than a full `sessionKey` cookie. Refresh tokens rotate on use. | Low (arguably safer than the cookie path) | VERIFIED |
| 7 | Cookie-path headers deliberately impersonate Chrome 131 to evade Cloudflare bot checks. This is a ToS-grey technique, not a data-exfiltration risk; any cookie-based clone needs the same. | Low (policy risk, not security) | VERIFIED |
| 8 | Loopback `NWListener` binds all interfaces for the seconds an OAuth login is pending; only a `/callback` with a matching PKCE `state` is accepted. | Low | VERIFIED code; exposure INFERRED |
| 9 | `codex-reset.com` third-party feed is polled by default (even with no Codex account configured — the guard is only the settings toggle). It receives no credentials, only a User-Agent identifying the app. Privacy leak = IP + app name to a community site every ≤30 min. | Low (privacy, not token) | VERIFIED |
| 10 | Logs pass through a redactor; trace-level raw bodies are not written to disk in Release. Diagnostic export is redacted. | Low | VERIFIED in source |

**Plain conclusion:** on the evidence available (binary strings, on-disk Keychain metadata, and the matching public MIT source), Usage4Claude does not exfiltrate or misuse the session token. The residual concerns are (i) supply-chain trust in an unnotarized, self-signed, self-updating app from a pseudonymous developer, and (ii) a vestigial on-disk cookie copy after browser login. Neither is evidence of malice.

## 9. Clone-relevant takeaways

- **Min macOS:** 13.0 (Info.plist). SwiftUI + AppKit; Swift concurrency; `LSUIElement = true`.
- **macOS APIs used:** `NSStatusItem`/`NSStatusBar.systemStatusBar` + `NSPopover` (menu bar), `SMAppService.mainApp` (launch at login), `UNUserNotificationCenter` (alerts), `SecItemAdd/CopyMatching/Delete` generic password (`kSecAttrService` = bundle id) for credentials, `URLSession` (30 s request / 60 s resource timeouts), `NWListener` (OAuth loopback), `WKWebView` with `.nonPersistent()` store (optional in-app login), `NSWorkspace` open-URL for links, Sparkle 2 (optional). Frameworks linked: see section 1.
- **Credential formats:** cookie `sessionKey` value — described by the app as "usually starts with `sk-ant-sid`" (Localizable), regex used for redaction `[a-zA-Z0-9-]{20,}`, accepted length 20–500; OAuth refresh token prefix `sk-ant-ort01-`; org id is a UUID (`[0-9a-f]{8}-…`).
- **Cookie-path endpoints & headers:** section 5 verbatim. Minimal working set INFERRED from the header builder's comments: `Cookie`, `user-agent` (browser-like), `origin`/`referer` = claude.ai, `sec-fetch-*`, `anthropic-client-platform: web_claude_ai`, `anthropic-client-version: 1.0.0`, `accept-language`. Disable HTTP/3 (`assumesHTTP3Capable = false`).
- **OAuth path:** authorize `https://claude.ai/oauth/authorize` (PKCE S256, `code_challenge_method`), token `https://console.anthropic.com/v1/oauth/token` (JSON body), usage `https://api.anthropic.com/api/oauth/usage` + `anthropic-beta: oauth-2025-04-20`, profile `…/api/oauth/profile`. Client id `9d1c250a-e61b-44d9-88ed-5944d1962f5e`, scope `user:profile`, redirect `http://localhost:<port>/callback` (avoid the ephemeral range 49152–65535; the app uses 1456/1458). Whether Anthropic permits third parties to use Claude Code's public client is a policy question — UNKNOWN; the app does it and the CLI binary contains the same id.
- **Response schema:** `UsageResponse` / `ExtraUsageResponse` in section 5; treat every window as optional; handle `limits[]` with `kind == "weekly_scoped"` for per-model weekly caps; `utilization`/`percent` are 0–100 doubles; `resets_at` is ISO-8601 with fractional seconds.
- **Polling cadence used by the original:** active 60 s; after 3 unchanged polls → 180 s; after 6 more → 300 s; after 12 more → 600 s; any change in utilization (>0.01) snaps back to 60 s (`SmartRefreshPolicy.swift`, `MonitoringMode.swift`). Fixed mode offers 60/180/300/600 s. Manual refresh has a cooldown. Extra reset-verification fetches at +1/+10/+30 s after `resets_at`. Refresh on wake and on popover open.
- **Notification rule:** warn when a limit crosses 90% (once per reset cycle, keyed by `resets_at`); "reset" when previous ≥90% and drop >30 points or `resets_at` changes.
- **Error taxonomy worth copying:** invalidURL, noData, sessionExpired (`permission_error`/`authentication_error` JSON or dead OAuth grant), cloudflareBlocked (HTML body / `cf-mitigated` header), unauthorized (401/403), rateLimited (429), decodingError, usageDashboardUnavailable (200 with all windows null), networkError, httpError(code).
- **Storage layout to mirror or improve:** one Keychain item `service=<bundle id>, account="accounts"` holding a JSON array of `{id, sessionKey, organizationId, organizationName, alias?, createdAt, provider}`. Improvement for a clone: ship with a Developer ID + notarization so the Keychain ACL is Team-ID-partitioned and survives updates; never copy cookies into `WKWebsiteDataStore.default()`; skip the third-party feed.
- **Diagnostics redaction regexes** (reusable): `sessionKey[=:]\s*["']?([a-zA-Z0-9-]{20,})["']?`, `Cookie:\s*sessionKey=([a-zA-Z0-9-]{20,})`, JWT `eyJ[A-Za-z0-9_-]{6,}\.[A-Za-z0-9_-]{6,}\.[A-Za-z0-9_-]+`, generic `"(access_?token|refresh_?token|id_?token|session_?token|token|authorization)"\s*:\s*"[^"]+"`.

## Open questions

1. Contents of `~/Library/Containers/xyz.fi5h.Usage4Claude/Data/Library/{Preferences,Cookies,WebKit,Caches,HTTPStorages,Logs}` — blocked by TCC in this shell. To verify the on-disk WebKit cookie copy (finding 3) and the `cachedOrganizations` pref, re-run `ls -laR` and `plutil -p …/Preferences/xyz.fi5h.Usage4Claude.plist` from a Full-Disk-Access terminal (redact values).
2. Whether the installed bundle is byte-identical to the GitHub v3.4.1 DMG (no local copy of that DMG; cdhash `8f925715…` recorded above for future comparison).
3. Whether Anthropic's terms allow third-party apps to use the Claude Code public OAuth client id; and whether the cookie-path browser impersonation is tolerated long-term.
4. Exact semantics of `member_dashboard_available` and of the `limits[]` `kind`/`group`/`severity` values — the source itself says these are unverified.
5. Whether Sparkle 2.9.2's default policy rejects an update signed by a *different* self-signed cert even when the EdDSA signature is valid (Sparkle's documented behavior says a signing-identity change requires the old app to be unsigned or an explicit opt-in; not re-derived here).
6. No keyboard shortcuts were found; UNKNOWN whether any exist beyond standard menu accelerators.
