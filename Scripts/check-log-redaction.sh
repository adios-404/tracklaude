#!/bin/sh
# Every log line must pass through AppLog (and so through LogRedactor). This fails if any
# source file other than AppLog.swift reaches the unified log directly, or writes to
# stdout/stderr — those bypass the redactor entirely. Backs spec user story 29.
set -eu
cd "$(dirname "$0")/.."

ALLOWED='Sources/tracklaude/AppLog.swift'
PATTERN='^import (os|OSLog)$|\bLogger\(|\bos_log\b|\b(print|debugPrint|NSLog|dump)\('

if offenders=$(grep -rnE "$PATTERN" Sources --include='*.swift' | grep -v "^$ALLOWED:"); then
    echo "FAIL: log calls outside $ALLOWED bypass LogRedactor:" >&2
    echo "$offenders" >&2
    exit 1
fi
echo "OK: every log call goes through $ALLOWED"
