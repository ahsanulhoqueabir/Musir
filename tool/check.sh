#!/usr/bin/env bash
# Pre-commit gate from the PRD: format, analyze (zero issues), tests.
set -euo pipefail
cd "$(dirname "$0")/.."
dart format --set-exit-if-changed lib test tool 2>/dev/null || { dart format lib test >/dev/null; echo "formatted files - re-stage"; }
out=$(flutter analyze 2>&1)
echo "$out" | tail -3
echo "$out" | grep -q "No issues found" || { echo "ANALYZE FAILED"; exit 1; }
flutter test 2>&1 | tail -2 | tee /tmp/test_tail.txt
grep -q "All tests passed" /tmp/test_tail.txt || { echo "TESTS FAILED"; exit 1; }
