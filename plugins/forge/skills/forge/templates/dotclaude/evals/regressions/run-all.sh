#!/usr/bin/env bash
# Regression-check runner: executes every NNNN-*.sh check in this directory.
# Each check is the permanent, runnable form of a confirmed past failure
# (issues-solved entry or promoted lesson) — rules prevent recurrence,
# these detect it. Exit 1 if any check fails. Run by /harness-audit and CI.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$PROJECT_ROOT"

pass=0
fail=0
for check in "$SCRIPT_DIR"/[0-9][0-9][0-9][0-9]-*.sh; do
  [ -e "$check" ] || continue
  name="$(basename "$check")"
  if out="$(bash "$check" 2>&1)"; then
    echo "PASS: $name"
    pass=$((pass + 1))
  else
    echo "FAIL: $name"
    echo "$out" | sed 's/^/  /'
    fail=$((fail + 1))
  fi
done

echo ""
echo "REGRESSIONS: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
