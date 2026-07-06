#!/usr/bin/env bash
# PostToolUse hook (matcher: Write|Edit): run TEST_CMD after a source change, update
# status.json's tests field, and only emit output on FAILURE — a passing run costs
# zero extra tokens. Skips gracefully if TEST_CMD is unset.
set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
[ -f "$PROJECT_ROOT/.claude/harness.env" ] && . "$PROJECT_ROOT/.claude/harness.env"
TEST_CMD="${TEST_CMD:-}"
SRC_EXTS="${SRC_EXTS:-}"

STATUS_FILE="$PROJECT_ROOT/.claude/state/status.json"
INPUT="$(cat)"

if ! command -v python3 >/dev/null 2>&1 || [ -z "$TEST_CMD" ] || [ -z "$SRC_EXTS" ]; then
  exit 0
fi

FILE_PATH="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d.get('tool_input',{}).get('file_path',''))" "$INPUT" 2>/dev/null || echo "")"

matched=0
for ext in $SRC_EXTS; do
  if [[ "$FILE_PATH" == *".$ext" ]]; then matched=1; break; fi
done
[ "$matched" = "1" ] || exit 0

cd "$PROJECT_ROOT" || exit 0

test_status="fail"
test_output="$(bash -c "$TEST_CMD" 2>&1)"
if [[ $? -eq 0 ]]; then
  test_status="pass"
fi

if [ -f "$STATUS_FILE" ]; then
  python3 - "$STATUS_FILE" "$test_status" <<'PY'
import json, sys
path, status = sys.argv[1:3]
with open(path) as f:
    data = json.load(f)
data.setdefault("health", {})
data["health"]["tests"] = status
with open(path, "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY
fi

if [[ "$test_status" == "fail" ]]; then
  tail_output="$(printf '%s' "$test_output" | tail -30)"
  python3 -c "
import json, sys
print(json.dumps({'systemMessage': 'Tests failed after editing ' + sys.argv[1] + '. Last 30 lines:\n' + sys.argv[2]}))
" "$FILE_PATH" "$tail_output"
fi

exit 0
