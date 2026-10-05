# 20: Notification banners show a blank icon

**What to fix:** every Alert banner shows macOS's blank placeholder (a grey rounded square
with a blueprint grid) instead of the Dial, although Finder, `NSWorkspace` and IconServices
all draw the Dial for `com.adios404.tracklaude`. Seen on macOS 27.0 (26A428), 2026-10-06.

**Blocked by:** none

**Status:** done (2026-10-06, commits 2029b11, 3e12016, 4d7e20a; v1.0.5)

- [x] The bundle carries `Contents/Resources/Assets.car` with an `AppIcon` app icon, and
      `CFBundleIconName = AppIcon` (keeping `CFBundleIconFile` and the .icns)
- [x] `Packaging/Assets.car` is compiled from the committed `.icns` by
      `Scripts/compile-assets.sh` (`make assets`, or the "Compile Assets.car" workflow,
      since the owner's Mac has no Xcode and so no `actool`)
- [x] A banner from the installed release shows the Dial

## Comments

**2026-10-06, cause.** From macOS 26, Notification Center draws an app's icon only from the
asset catalog `CFBundleIconName` names. With only `CFBundleIconFile` + `.icns`, every banner
gets the placeholder that IconServices returns for an unknown app. Three projects hit the
same thing in September 2026 and fixed it with `Assets.car` + `CFBundleIconName`:
We-Are-PLEH/ouija#5 (measured exactly our evidence: `NSWorkspace.icon` fine, banner blank),
allenhutchison/breakbar#41 and vlondon/AgentUsage#2 (which also needed one
`killall NotificationCenter` afterwards). None of this is documented by Apple.

Ruled out first, each followed by a test banner that was still blank: restarting
`NotificationCenter`, restarting `usernoted`, `lsregister -u` + `-f` of the installed app
(+ unregistering dead build paths) followed by another NotificationCenter restart. The
`Info.plist` keys `UNNotificationIcons…` that NotificationPreferences.framework reads are for
Apple's own notification bundles only (decompiled `UNCNotificationSourceDescription`), so
they are not a fix.

**2026-10-06, v1.0.5 shipped, still blank here.** Commits 2029b11, 3e12016, 4d7e20a; tag
v1.0.5; tap PR #11 merged after its audit passed; `brew upgrade` installed it (Info.plist has
`CFBundleIconName`, Resources has `Assets.car`; `assetutil --info` lists AppIcon 16–1024 px).
Test banners, posted by a scratch helper with the same bundle id, were still blank after
`killall NotificationCenter`, also once the helper itself carried the same catalog. Not yet
seen: a real Alert from the relaunched 1.0.5 app.

Open candidates, untested:
1. Notification Center resolves the bundle id to another registered copy (third-party
   precedent for sounds: YoanWai/agent-manager#490). LaunchServices still lists a broken
   `dev-build/tracklaude.app` (v0.1, no Info.plist, no Resources) from the 2026-10-03
   session's scratchpad, and `dist/tracklaude.app`. A missing-sound probe did not log a path.
2. A stale image in IconServices' root-owned store (`/Library/Caches/com.apple.iconservices.store`):
   NotificationCenter logs "Persistent store lookup returned found - full match" for the
   banner. Clearing it needs the owner's admin password.
3. Both are cleared by a reboot, which has not been tried.

**2026-10-06, fixed.** Deleted the broken `dev-build` copy (unregistered first), then the
owner cleared both IconServices caches with the command now in README › Questions ›
"Notifications show a blank icon". The next test banner showed the Dial (grey: the owner's
icon style is Clear Dark). The shared store went from ~1,700 entries to 20, so the blank
image Notification Center kept loading ("Persistent store lookup returned found") lived
there and survived every process restart. `iconservicesd` did not die (`killall` left
the same pid), so the file deletion is what mattered.

Not proven on this Mac: whether the catalog alone, on a clean Mac that never cached a blank
icon, is enough. The three sources say it is needed on macOS 26+, so it stays. An upgrade
from ≤1.0.4 can still carry the cached blank image, hence the README entry. The scratch
helper that posted the test banners (same bundle id) is deleted.
