#!/usr/bin/env bash
# Stop hook: optionally regenerate the dependency graph (GRAPH_CMD from harness.env,
# non-fatal) and remind to keep TASKS.md and the activity log current.
set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT" || exit 0
[ -f .claude/harness.env ] && . .claude/harness.env
GRAPH_CMD="${GRAPH_CMD:-}"

if [ -n "$GRAPH_CMD" ]; then
  bash -c "$GRAPH_CMD" >/tmp/harness-graph.log 2>&1 || true
fi

python3 - <<'PY'
import json
print(json.dumps({"systemMessage": "Before ending: check .claude/tasks/TASKS.md is current (any task you worked on this session moved to the right status?), and if this session contained a user correction or repeated failure, run /learn."}))
PY
