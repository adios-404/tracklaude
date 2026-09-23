#!/bin/sh
# Exercises Scripts/bump-cask.sh against a copy of a real-shaped cask: the release job
# runs it once per tag, unattended, so a regex that silently stops matching would open a
# tap pull request carrying the old hash.
set -eu
cd "$(dirname "$0")/.."

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fails=0
fail() { echo "FAIL: $*" >&2; fails=$((fails + 1)); }

sha_old=$(printf '1%.0s' $(seq 64))
sha_new=$(printf 'a%.0s' $(seq 64))
fixture() {
    cat > "$work/tracklaude.rb" <<CASK
cask "tracklaude" do
  version "0.1.0"
  sha256 "$sha_old"

  url "https://github.com/adios-404/tracklaude/releases/download/v#{version}/tracklaude-v#{version}.zip"
  livecheck do
    url :url
  end
end
CASK
}

fixture
sh Scripts/bump-cask.sh 1.2.3 "$sha_new" "$work/tracklaude.rb" >/dev/null
grep -qx '  version "1.2.3"' "$work/tracklaude.rb" || fail "version not bumped"
grep -qx "  sha256 \"$sha_new\"" "$work/tracklaude.rb" || fail "sha256 not bumped"
grep -q 'download/v#{version}/tracklaude-v#{version}.zip' "$work/tracklaude.rb" || fail "url line changed"
[ "$(wc -l < "$work/tracklaude.rb")" -eq 9 ] || fail "line count changed"

for bad in "1.2" "v1.2.3" "1.2.3-rc1" ""; do
    fixture
    if sh Scripts/bump-cask.sh "$bad" "$sha_new" "$work/tracklaude.rb" 2>/dev/null; then
        fail "accepted version '$bad'"
    fi
    grep -qx '  version "0.1.0"' "$work/tracklaude.rb" || fail "version '$bad' modified the cask"
done

for bad in "abc" "$(printf 'A%.0s' $(seq 64))" "${sha_new}0"; do
    fixture
    if sh Scripts/bump-cask.sh 1.2.3 "$bad" "$work/tracklaude.rb" 2>/dev/null; then
        fail "accepted sha256 '$bad'"
    fi
done

fixture
sed -i '' '/sha256/d' "$work/tracklaude.rb"
if sh Scripts/bump-cask.sh 1.2.3 "$sha_new" "$work/tracklaude.rb" 2>/dev/null; then
    fail "accepted a cask with no sha256 line"
fi
grep -qx '  version "0.1.0"' "$work/tracklaude.rb" || fail "half-bumped a cask with no sha256 line"

if sh Scripts/bump-cask.sh 1.2.3 "$sha_new" "$work/missing.rb" 2>/dev/null; then
    fail "accepted a missing cask file"
fi

[ "$fails" -eq 0 ] || exit 1
echo "OK: bump-cask.sh rewrites version and sha256 only, and refuses bad input"
