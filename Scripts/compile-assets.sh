#!/bin/sh
# Compiles Packaging/Assets.car — the app icon as an asset catalog — from the committed
# Packaging/AppIcon.icns, so both hold the same pixels. The .car is committed like the
# .icns, so `make bundle` never needs this script.
#
# Why the catalog exists at all: from macOS 26, Notification Center draws an app's icon
# only from the Assets.car that CFBundleIconName names. With just CFBundleIconFile and an
# .icns, Finder, the Dock and NSWorkspace show the icon but every notification banner
# shows the blank placeholder (verified on macOS 27.0, 2026-10-06; same finding in
# We-Are-PLEH/ouija#5, allenhutchison/breakbar#41, vlondon/AgentUsage#2).
#
# Needs actool, which ships only with full Xcode — not the Command Line Tools. Without
# Xcode, run the "Compile Assets.car" workflow on GitHub and commit its artefact
# (README › Build from source).
set -eu
cd "$(dirname "$0")/.."

ICNS=Packaging/AppIcon.icns
OUT=Packaging/Assets.car
MIN_MACOS="$(sed -n '/LSMinimumSystemVersion/{n;s/.*<string>\(.*\)<\/string>.*/\1/p;}' Packaging/Info.plist.in)"

xcrun --find actool >/dev/null 2>&1 || {
    echo "FAIL: actool not found — it ships with Xcode only. Use the 'Compile Assets.car' workflow instead." >&2
    exit 2
}
[ -n "$MIN_MACOS" ] || { echo "FAIL: no LSMinimumSystemVersion in Packaging/Info.plist.in" >&2; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# The .icns unpacks to icon_<size>x<size>[@2x].png, the names the appiconset lists below.
iconutil -c iconset "$ICNS" -o "$WORK/AppIcon.iconset"
SET="$WORK/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$SET"
cp "$WORK"/AppIcon.iconset/*.png "$SET/"
printf '{ "info" : { "author" : "xcode", "version" : 1 } }\n' > "$WORK/Assets.xcassets/Contents.json"
{
    printf '{\n  "images" : [\n'
    sep=''
    for size in 16 32 128 256 512; do
        for scale in 1 2; do
            suffix=''; [ "$scale" = 2 ] && suffix='@2x'
            file="icon_${size}x${size}${suffix}.png"
            [ -f "$SET/$file" ] || { echo "FAIL: $ICNS has no $file" >&2; exit 1; }
            printf '%b    { "filename" : "%s", "idiom" : "mac", "scale" : "%sx", "size" : "%sx%s" }' \
                "$sep" "$file" "$scale" "$size" "$size"
            sep=',\n'
        done
    done
    printf '\n  ],\n  "info" : { "author" : "xcode", "version" : 1 }\n}\n'
} > "$SET/Contents.json"

mkdir -p "$WORK/out"
xcrun actool "$WORK/Assets.xcassets" --compile "$WORK/out" \
    --platform macosx --target-device mac --minimum-deployment-target "$MIN_MACOS" \
    --app-icon AppIcon --output-partial-info-plist "$WORK/out/partial.plist" \
    --errors --warnings --output-format human-readable-text

[ -s "$WORK/out/Assets.car" ] || { echo "FAIL: actool produced no Assets.car" >&2; exit 1; }
cp "$WORK/out/Assets.car" "$OUT"
echo "Wrote $OUT"
