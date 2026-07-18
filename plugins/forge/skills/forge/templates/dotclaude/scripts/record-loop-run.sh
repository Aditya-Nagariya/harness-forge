#!/usr/bin/env bash
# Stamps .claude/state/last-loop-run.json with the current UTC timestamp.
# Called as /loop's final step so capability-gate.sh knows the loop ran.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE_FILE="$PROJECT_ROOT/.claude/state/last-loop-run.json"

mkdir -p "$(dirname "$STATE_FILE")"
python3 -c "
import json
from datetime import datetime, timezone
json.dump({'last_run': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}, open('$STATE_FILE', 'w'))
"
echo "recorded loop run at $(python3 -c "import json; print(json.load(open('$STATE_FILE'))['last_run'])")"
