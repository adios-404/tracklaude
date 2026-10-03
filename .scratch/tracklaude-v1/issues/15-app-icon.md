# 15: A designed app icon

**What to build:** a properly designed logo / app icon — the owner asked for real design
work, not a hand-written SVG (2026-09-17). v1.0.0 and v1.0.1 shipped without one: the
bundle has no `CFBundleIconFile`, so Finder, Launchpad, Gatekeeper's dialog and System
Settings › Login Items show the generic app icon. The menu-bar glyph (an SF Symbol gauge,
spec › Menu bar) is separate and stays.

**Blocked by:** None

**Status:** done (2026-10-03, commit e8324f6; shipped in v1.0.3)

- [x] A design the owner approves, as a 1024 × 1024 master (`docs/icon.png`)
- [x] `make icon` builds `Packaging/AppIcon.icns` (`iconutil`, all sizes; committed), `make bundle` copies it and `CFBundleIconFile` is set
- [x] README heading shows the icon
- [x] Shipped in v1.0.3; the brew-installed app carries it (owner looked in Finder)

## Comments

**2026-10-03.** Raised late: the project memory said to bring this up before the v1 cut, and
it was missed. Nothing else depends on it.

**2026-10-03 — closed.** Ten directions were sketched on a private artifact page
(https://claude.ai/artifact/VVDDaor6rWLKKXPtUKrqH8); the owner picked 1, the Dial, which
matches the menu-bar gauge glyph. `Scripts/render-icon.swift` draws it with Core Graphics
(superellipse n = 5 body on the 824-unit grid, navy gradient, mint → amber arc at 70 %,
ticks, tapered needle); ≤ 32 px gets a simpler drawing without ticks and with heavier
strokes. The first render sat too high and left the bottom third empty; the dial centre
moved from y 592 to 650. Not done: a designer's pass — the owner chose to ship this.
