#!/bin/sh
# Every log line must pass through AppLog (and so through LogRedactor). This fails if any
# source file other than AppLog.swift reaches the unified log directly, prints to
# stdout/stderr, or writes a file — all of which would bypass the redactor. Backs spec
# user story 29 and spec › Logging ("no log files written by the app").
set -eu
cd "$(dirname "$0")/.."

ALLOWED='Sources/tracklaude/AppLog.swift'
PATTERN='^import (os|OSLog|os\.log)$|\bLogger\(|\bos_log\b|\b(print|debugPrint|NSLog|dump|fputs)\(|\bFileHandle\b|\.write\(to'

[ -d Sources ] || { echo "FAIL: no Sources/ directory here" >&2; exit 2; }

# Why the `|| true`: grep exits 1 when nothing matches, which is the passing case.
offenders=$(grep -rnE "$PATTERN" Sources --include='*.swift' | grep -v "^$ALLOWED:" || true)

if [ -n "$offenders" ]; then
    echo "FAIL: log or file writes outside $ALLOWED bypass LogRedactor:" >&2
    echo "$offenders" >&2
    exit 1
fi
echo "OK: every log call goes through $ALLOWED and nothing writes files"
