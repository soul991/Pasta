#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

TASK_LOG=$(mktemp /private/tmp/pasta-test-counts.XXXXXX)
trap 'rm -f "$TASK_LOG"' EXIT

run_and_report() {
    "$@" >"$TASK_LOG" 2>&1
    grep -E 'Test Suite Summary:|Section 8 Test Results:' "$TASK_LOG"
}

echo "== Debug PastaTests =="
run_and_report swift run PastaTests

echo "== Release PastaTests =="
run_and_report swift run -c release PastaTests

echo "== Section 8 (debug binary) =="
PASTA_BIN=.build/debug/Pasta ./scripts/run_section8_tests.sh >"$TASK_LOG" 2>&1
grep -E 'Section 8 Test Results:' "$TASK_LOG"
