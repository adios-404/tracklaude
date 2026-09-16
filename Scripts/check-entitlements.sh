#!/bin/sh
# The signed app carries exactly app-sandbox, network.client and network.server — nothing
# more (spec › Packaging; backs user story 28). Reads the entitlements codesign actually
# embedded, not the source plist, so a Makefile slip is caught too.
set -eu

APP="${1:-dist/tracklaude.app}"
[ -d "$APP" ] || { echo "FAIL: no app bundle at $APP (run 'make sign' first)" >&2; exit 2; }

expected=$(printf 'com.apple.security.app-sandbox\ncom.apple.security.network.client\ncom.apple.security.network.server\n')
actual=$(codesign -d --entitlements :- "$APP" 2>/dev/null | grep -o 'com\.apple\.security[a-z.-]*' | sort -u)

if [ "$expected" != "$actual" ]; then
    echo "FAIL: $APP entitlements differ from the allowlist" >&2
    echo "expected:" >&2; echo "$expected" | sed 's/^/  /' >&2
    echo "actual:" >&2;   echo "${actual:-(none)}" | sed 's/^/  /' >&2
    exit 1
fi
echo "OK: $APP entitlements are exactly app-sandbox, network.client, network.server"
