#!/bin/sh
# The built binary names no host other than Anthropic's and the loopback used for OAuth
# (spec › Testing Decisions, "one property test"; backs user story 26). Runs `strings` over
# the binary and fails on any URL host, IPv4 literal or dotted name under a public TLD
# that is not on the allowlist.
#
# Limits, stated so nobody over-reads a green run: a host assembled at runtime from
# pieces, or one under a TLD missing from the list below, is invisible to `strings`.
# Source review remains the boundary; this catches the honest mistake of a new literal.
set -eu

BINARY="${1:-.build/release/tracklaude}"
ALLOWED='claude.ai console.anthropic.com api.anthropic.com localhost 127.0.0.1'
TLDS='com|ai|net|org|io|dev|co|app|me|xyz|cloud|sh|us|uk|info|biz|tv|gg|ly|to|zip|so|cc|eu|de|fr|in|ca|au|jp|cn|ru|nl|se|ch|it|es|br|kr'

[ -f "$BINARY" ] || { echo "FAIL: no binary at $BINARY (run 'make build' first)" >&2; exit 2; }

text=$(strings -n 6 "$BINARY")

# Each extractor may match nothing; `|| true` keeps that from tripping `set -e`.
url_hosts=$(echo "$text" | grep -oE '[a-zA-Z][a-zA-Z0-9+.-]*://[^/"'"'"'<> ]+' | sed -E 's#^[^/]*://##; s#:[0-9]*$##' || true)
ipv4=$(echo "$text" | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' || true)
tld_names=$(echo "$text" | grep -oiE '\b[a-z0-9-]+(\.[a-z0-9-]+)+\b' | grep -iE "\.($TLDS)$" || true)
loopback=$(echo "$text" | grep -oE '\blocalhost\b' || true)

found=$(printf '%s\n%s\n%s\n%s\n' "$url_hosts" "$ipv4" "$tld_names" "$loopback" | tr 'A-Z' 'a-z' | sort -u | grep -v '^$' || true)

strays=''
for host in $found; do
    case " $ALLOWED " in
        *" $host "*) ;;
        *) strays="$strays $host" ;;
    esac
done

if [ -n "$strays" ]; then
    echo "FAIL: $BINARY names hosts outside the allowlist:$strays" >&2
    exit 1
fi
echo "OK: $BINARY names only:$(printf ' %s' $found)"
