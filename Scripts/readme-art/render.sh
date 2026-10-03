#!/bin/sh
# Redraws the README's pictures into docs/readme/: the header, the hero scene and the
# menu-bar states, each light and dark, plus social-preview.png for Settings › Social preview.
# `make readme-art` runs this. Needs the Command Line Tools, python3 and Google Chrome
# (override with CHROME=...); pngquant and oxipng, if installed, shrink the PNGs.
set -eu
cd "$(dirname "$0")"
OUT=../../docs/readme
CHROME=${CHROME:-"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"}
[ -x "$CHROME" ] || { echo "FAIL: no Chrome at $CHROME (set CHROME=...)" >&2; exit 2; }
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OUT"

# 1. The app's real views, drawn by AppKit with a sample reading. Why the arguments: the
#    blue accent and US English are macOS's defaults, so the pictures match a fresh Mac
#    rather than the machine that happened to render them.
swift build -c release --package-path . >/dev/null
.build/release/ReadmeArt "$WORK" -AppleAccentColor 4 -AppleLocale en_US

# 2. The header: the word as outlines, then the icon and word together.
swift web/glyphs.swift web/InstrumentSans.ttf 100 640 94 -0.025 tracklaude > "$WORK/wordmark.json"
python3 web/lockup.py "$WORK/wordmark.json" "$OUT"

# 3. The composed pictures. Each page sets its title to "ready" once every image has
#    loaded, or to "error: …" — checked with --dump-dom, since a screenshot of a page with a
#    missing image still succeeds.
clock=$(python3 -c 'import json, sys, urllib.parse; print(urllib.parse.quote(json.load(open(sys.argv[1]))["clock"]))' "$WORK/meta.json")
page() { # page <out.png> <width> <height> <scale> <url> [transparent]
    background=""
    [ "${6:-}" = transparent ] && background="--default-background-color=00000000"
    set -- "$1" "$2" "$3" "$4" "file://$PWD/web/$5"
    "$CHROME" --headless=new --disable-gpu --hide-scrollbars --virtual-time-budget=5000 \
        --window-size="$2,$3" --dump-dom "$5" 2>/dev/null | grep -q '<title>ready</title>' \
        || { echo "FAIL: $5 did not finish loading" >&2; exit 1; }
    "$CHROME" --headless=new --disable-gpu --hide-scrollbars --virtual-time-budget=5000 \
        --window-size="$2,$3" --force-device-scale-factor="$4" $background \
        --screenshot="$1" "$5" 2>/dev/null
    [ -s "$1" ] || { echo "FAIL: no screenshot at $1" >&2; exit 1; }
}
for theme in light dark; do
    # 640 × 430 points at 2.6x: 1664 px wide, twice the README's widest column.
    page "$OUT/hero-$theme.png" 640 430 2.6 "scene.html?theme=$theme&art=$WORK&clock=$clock" transparent
    for state in live stale nowindow signedout; do
        page "$OUT/state-$state-$theme.png" 250 40 3 "chip.html?theme=$theme&state=$state&art=$WORK" transparent
    done
done
page "$OUT/social-preview.png" 1280 640 1 "social.html?art=$WORK&icon=file://$PWD/../../docs/icon.png&clock=$clock"

# Smaller downloads for the README. pngquant at 88–98 measured 42 dB PSNR on the hero's
# gradients (2026-10-03) — no visible change — at a third of the size; it leaves a file
# alone when it cannot reach that quality. oxipng is lossless.
if command -v pngquant >/dev/null; then
    for png in "$OUT"/*.png; do
        pngquant --quality=88-98 --speed 1 --strip --force --ext .png "$png" || echo "kept as drawn: $png"
    done
fi
if command -v oxipng >/dev/null; then
    oxipng --quiet -o 4 --strip safe "$OUT"/*.png
fi
ls -l "$OUT"
