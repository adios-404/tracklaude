#!/bin/sh
# Rewrites the `version` and `sha256` lines of the tap's cask for a new release (ticket 11).
# Run by the release workflow's tap job; portable sh + POSIX sed so it works on any runner.
# Refuses rather than guesses: a pre-release version, a malformed hash, or a cask whose
# lines no longer look as expected each fail with the cask left untouched.
set -eu

usage() { echo "usage: $0 <X.Y.Z> <sha256-hex> <path/to/cask.rb>" >&2; exit 2; }
[ $# -eq 3 ] || usage
version=$1 sha=$2 cask=$3

echo "$version" | grep -Eqx '[0-9]+\.[0-9]+\.[0-9]+' \
    || { echo "FAIL: version '$version' is not X.Y.Z (pre-releases never reach the tap)" >&2; exit 1; }
echo "$sha" | grep -Eqx '[0-9a-f]{64}' \
    || { echo "FAIL: '$sha' is not a lowercase SHA-256" >&2; exit 1; }
[ -f "$cask" ] || { echo "FAIL: no cask at $cask" >&2; exit 1; }

for field in version sha256; do
    count=$(grep -Ec "^  $field \"[^\"]*\"$" "$cask" || true)
    [ "$count" -eq 1 ] || { echo "FAIL: expected one '$field' line in $cask, found $count" >&2; exit 1; }
done

# Why a temp file and mv: a sed failure halfway must not leave a half-bumped cask.
tmp="$cask.tmp.$$"
trap 'rm -f "$tmp"' EXIT
sed -e "s/^  version \"[^\"]*\"$/  version \"$version\"/" \
    -e "s/^  sha256 \"[^\"]*\"$/  sha256 \"$sha\"/" "$cask" > "$tmp"
mv "$tmp" "$cask"
echo "OK: $cask now at $version ($sha)"
