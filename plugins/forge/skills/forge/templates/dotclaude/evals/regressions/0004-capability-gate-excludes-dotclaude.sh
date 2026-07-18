#!/usr/bin/env bash
# Regression check: capability-gate.sh must NEVER block a Write/Edit under
# .claude/ — otherwise /loop's own first action (/learn writing a lesson file)
# would trip the gate before /loop could ever satisfy it (self-inflicted
# deadlock). Derived from the R1+R10 combined design's anti-deadlock rule.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

HOOK=".claude/hooks/capability-gate.sh"
if [ ! -f "$HOOK" ]; then
  echo "capability-gate.sh not found at $HOOK"
  exit 1
fi

# Force worst-case conditions: loop badly overdue, no gate-checked flag —
# if the exclusion works, none of this should matter for a .claude/ path.
STATE_DIR="$(mktemp -d)"
export FORGE_STATE_DIR="$STATE_DIR"
export LOOP_OVERDUE_HOURS="24"
echo '{"last_run": "2000-01-01T00:00:00Z"}' > "$STATE_DIR/last-loop-run.json"

out="$(echo '{"tool_input":{"file_path":"/repo/.claude/memory/lessons/0009-test.md","content":"x"}}' | bash "$HOOK")"
exit_code=$?
rm -rf "$STATE_DIR"

if [ "$exit_code" != "0" ]; then
  echo "FAIL: capability-gate.sh blocked a .claude/ path (exit $exit_code, output: $out)"
  exit 1
fi
exit 0
