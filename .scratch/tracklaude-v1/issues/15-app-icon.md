# 15: A designed app icon

**What to build:** a properly designed logo / app icon — the owner asked for real design
work, not a hand-written SVG (2026-09-17). v1.0.0 and v1.0.1 shipped without one: the
bundle has no `CFBundleIconFile`, so Finder, Launchpad, Gatekeeper's dialog and System
Settings › Login Items show the generic app icon. The menu-bar glyph (an SF Symbol gauge,
spec › Menu bar) is separate and stays.

**Blocked by:** None

**Status:** needs-triage — the owner decides who designs it (a designer, a design tool, or
directions for an agent to iterate on) and what it should say.

- [ ] A design the owner approves, as a 1024 × 1024 master
- [ ] `make bundle` builds `AppIcon.icns` from it (`iconutil`, all sizes) and sets `CFBundleIconFile`
- [ ] README screenshot / heading updated if the mark appears there
- [ ] Shipped in a patch release; the brew-installed app shows it in Finder

## Comments

**2026-10-03.** Raised late: the project memory said to bring this up before the v1 cut, and
it was missed. Nothing else depends on it.
