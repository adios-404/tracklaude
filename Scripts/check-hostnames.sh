#!/bin/sh
# The app names no host other than Anthropic's and the loopback used for OAuth (spec ›
# Testing Decisions, "one property test"; backs user story 26). Two layers, both against
# one allowlist: `strings` over the built binary, and the same extraction over Sources/.
#
# Why two layers: Swift keeps string literals of 15 bytes or fewer inline in the String
# value, so they never reach the binary's string table — "127.0.0.1" is in the source and
# `strings` cannot find it (verified 2026-09-17). A short stray host such as "sentry.io"
# would pass the binary layer; the source layer catches it.
#
# Limits, stated so nobody over-reads a green run: a host assembled at runtime from
# pieces, or one under a TLD missing from the list below, is invisible to both layers.
# The list leaves out TLDs that double as ordinary tokens (.app, .sh, .so, .it, .in) —
# a bundle name or script path in a comment must not read as a host.
# Source review remains the boundary; this catches the honest mistake of a new literal.
set -eu
cd "$(dirname "$0")/.."

BINARY="${1:-.build/release/tracklaude}"
ALLOWED='claude.ai console.anthropic.com api.anthropic.com localhost 127.0.0.1'
TLDS='com|ai|net|org|io|dev|co|me|xyz|cloud|us|uk|info|biz|tv|gg|ly|to|cc|eu|de|fr|ca|au|jp|cn|ru|nl|se|ch|es|br|kr'
MIN_STRING_LENGTH=6

[ -f "$BINARY" ] || { echo "FAIL: no binary at $BINARY (run 'make build' first)" >&2; exit 2; }

# Reads text on stdin, prints every URL host, IPv4 literal, dotted name under a listed
# TLD, and `localhost`, lower-cased and de-duplicated. Each extractor may match nothing;
# `|| true` keeps that from tripping `set -e`.
hosts_in() {
    text=$(cat)
    # Why printf: /bin/sh's echo interprets backslash escapes, and `\c` in the input
    # would truncate everything after it — hiding a host from the check.
    url_hosts=$(printf '%s\n' "$text" | grep -oE '[a-zA-Z][a-zA-Z0-9+.-]*://[^/"'"'"'<> ]+' | sed -E 's#^[^/]*://##; s#^[^/@]*@##; s#[:/].*$##' || true)
    ipv4=$(printf '%s\n' "$text" | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' || true)
    tld_names=$(printf '%s\n' "$text" | grep -oiE '\b[a-z0-9-]+(\.[a-z0-9-]+)+\b' | grep -iE "\.($TLDS)$" || true)
    loopback=$(printf '%s\n' "$text" | grep -oE '\blocalhost\b' || true)
    printf '%s\n%s\n%s\n%s\n' "$url_hosts" "$ipv4" "$tld_names" "$loopback" | tr 'A-Z' 'a-z' | sort -u | grep -v '^$' || true
}

strays_in() {
    for host in $1; do
        case " $ALLOWED " in
            *" $host "*) ;;
            *) printf ' %s' "$host" ;;
        esac
    done
}

binary_hosts=$(strings -n "$MIN_STRING_LENGTH" "$BINARY" | hosts_in)
source_hosts=$(cat $(find Sources -name '*.swift') | hosts_in)

binary_strays=$(strays_in "$binary_hosts")
source_strays=$(strays_in "$source_hosts")

status=0
if [ -n "$binary_strays" ]; then
    echo "FAIL: $BINARY names hosts outside the allowlist:$binary_strays" >&2
    status=1
fi
if [ -n "$source_strays" ]; then
    echo "FAIL: Sources/ names hosts outside the allowlist:$source_strays" >&2
    status=1
fi
[ "$status" -eq 0 ] || exit "$status"
echo "OK: $BINARY names only:$(printf ' %s' $binary_hosts)"
echo "OK: Sources/ names only:$(printf ' %s' $source_hosts)"
