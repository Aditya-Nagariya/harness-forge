#!/usr/bin/env bash
# Regression check derived from lesson 0005's rule: every deterministic PreToolUse
# gate hook must have at least one fixture that expects exit 2 (the block path).
# A gate whose block path is untested has "silently allow" as its failure mode.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

GATES="protect-files scan-secrets block-dangerous-commands"
failed=0
for gate in $GATES; do
  dir=".claude/hooks/tests/fixtures/$gate"
  if [ ! -d "$dir" ]; then
    echo "$gate: no fixture directory at all"
    failed=1
    continue
  fi
  if ! grep -l '"expect_exit": 2' "$dir"/*.json >/dev/null 2>&1; then
    echo "$gate: no block-path fixture (expect_exit 2)"
    failed=1
  fi
done
exit $failed
