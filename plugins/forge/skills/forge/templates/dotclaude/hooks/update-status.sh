#!/usr/bin/env bash
# PostToolUse hook (matcher: Write|Edit): after an edit to a source file, re-run
# BUILD_CMD/LINT_CMD from .claude/harness.env and update status.json's health block —
# live broken/working tracking driven by the real toolchain's own signal, not a guess.
# Skips gracefully if commands are unset. Silent on success.
set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
[ -f "$PROJECT_ROOT/.claude/harness.env" ] && . "$PROJECT_ROOT/.claude/harness.env"
BUILD_CMD="${BUILD_CMD:-}"
LINT_CMD="${LINT_CMD:-}"
SRC_EXTS="${SRC_EXTS:-}"

STATUS_FILE="$PROJECT_ROOT/.claude/state/status.json"
LOG_FILE="$PROJECT_ROOT/.claude/memory/activity-log.md"

INPUT="$(cat)"

if ! command -v python3 >/dev/null 2>&1 || [ -z "$SRC_EXTS" ]; then
  exit 0
fi

FILE_PATH="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d.get('tool_input',{}).get('file_path',''))" "$INPUT" 2>/dev/null || echo "")"

matched=0
for ext in $SRC_EXTS; do
  if [[ "$FILE_PATH" == *".$ext" ]]; then matched=1; break; fi
done
[ "$matched" = "1" ] || exit 0

cd "$PROJECT_ROOT" || exit 0

build_status="unknown"
lint_status="unknown"
if [ -n "$BUILD_CMD" ]; then
  build_status="fail"
  bash -c "$BUILD_CMD" >/tmp/harness-build.log 2>&1 && build_status="pass"
fi
if [ -n "$LINT_CMD" ]; then
  lint_status="fail"
  bash -c "$LINT_CMD" >/tmp/harness-lint.log 2>&1 && lint_status="pass"
fi

prev_build="unknown"
if [ -f "$STATUS_FILE" ]; then
  prev_build="$(python3 -c "import json; print(json.load(open('$STATUS_FILE')).get('health',{}).get('build','unknown'))" 2>/dev/null || echo unknown)"
fi

timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [ -f "$STATUS_FILE" ]; then
  python3 - "$STATUS_FILE" "$build_status" "$lint_status" "$timestamp" <<'PY'
import json, sys
path, build, lint, ts = sys.argv[1:5]
with open(path) as f:
    data = json.load(f)
data.setdefault("health", {})
data["health"]["build"] = build
data["health"]["lint"] = lint
data["health"]["last_checked"] = ts
with open(path, "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY
fi

if [ -n "$BUILD_CMD" ] && [[ "$prev_build" != "$build_status" ]]; then
  date_only="$(date -u +%Y-%m-%d)"
  echo "[$date_only] [hook:update-status] — build health changed: $prev_build -> $build_status (after edit to $FILE_PATH)" >> "$LOG_FILE"
fi

exit 0
