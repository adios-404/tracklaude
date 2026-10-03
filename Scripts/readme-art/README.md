# README pictures

`make readme-art` redraws everything in [`docs/readme/`](../../docs/readme): the header,
the hero picture and the menu-bar states (each light and dark), and `social-preview.png`,
the card GitHub shows when the repository is linked (uploaded by hand under
*Settings › Social preview*).

The app in these pictures is the app. [`ReadmeArt`](Sources/ReadmeArt/main.swift) draws
the real `PopoverView` and `UsageRowsView` (symlinks to the files in
[`Sources/tracklaude`](../../Sources/tracklaude)) through AppKit with a sample reading:
42 % of the 5-hour window, resetting in 2h14m. Only what an off-screen render cannot
produce is drawn around it in [`web/`](web): the menu bar's surroundings, the popover's
glass and the wallpaper, whose dial is the app icon's.

| Step | Tool | Makes |
|---|---|---|
| 1 | `ReadmeArt` (Swift, this package) | the popover, the menu-bar item in four states, the system glyphs, at 4x |
| 2 | [`glyphs.swift`](web/glyphs.swift), [`lockup.py`](web/lockup.py) | `lockup-*.svg`: the icon, whose needle sweeps to 70 % on load, beside the name |
| 3 | headless Chrome with [`scene.html`](web/scene.html), [`chip.html`](web/chip.html), [`social.html`](web/social.html) | `hero-*.png`, `state-*.png`, `social-preview.png` |
| 4 | `pngquant`, `oxipng` (optional) | smaller files |

Needs the Command Line Tools, `python3` and Google Chrome (`CHROME=/path/to/chrome` to use
another). Rendering takes about a minute and a half.

The name is set in [Instrument Sans](https://github.com/Instrument/instrument-sans) (SIL
Open Font License, [`web/OFL.txt`](web/OFL.txt)). The app's own text is SF, which Apple
licenses for interface mock-ups only, so it appears in the pictures of the app and nowhere
else.
