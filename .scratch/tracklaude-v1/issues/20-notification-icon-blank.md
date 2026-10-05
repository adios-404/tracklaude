# 20: Notification banners show a blank icon

**What to fix:** every Alert banner shows macOS's blank placeholder (a grey rounded square
with a blueprint grid) instead of the Dial, although Finder, `NSWorkspace` and IconServices
all draw the Dial for `com.adios404.tracklaude`. Seen on macOS 27.0 (26A428), 2026-10-06.

**Blocked by:** none

**Status:** in progress

- [ ] The bundle carries `Contents/Resources/Assets.car` with an `AppIcon` app icon, and
      `CFBundleIconName = AppIcon` (keeping `CFBundleIconFile` and the .icns)
- [ ] `Packaging/Assets.car` is compiled from the committed `.icns` by
      `Scripts/compile-assets.sh` (`make assets`, or the "Compile Assets.car" workflow,
      since the owner's Mac has no Xcode and so no `actool`)
- [ ] A banner from the installed release shows the Dial

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
