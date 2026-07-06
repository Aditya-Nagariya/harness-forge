#!/usr/bin/env bash
# PostToolUse hook (matcher: Write|Edit): auto-format after a source-file edit via
# FMT_CMD from .claude/harness.env. Silent on success; skips if FMT_CMD is unset.
set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
[ -f "$PROJECT_ROOT/.claude/harness.env" ] && . "$PROJECT_ROOT/.claude/harness.env"
FMT_CMD="${FMT_CMD:-}"
SRC_EXTS="${SRC_EXTS:-}"

INPUT="$(cat)"

if ! command -v python3 >/dev/null 2>&1 || [ -z "$FMT_CMD" ] || [ -z "$SRC_EXTS" ]; then
  exit 0
fi

FILE_PATH="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d.get('tool_input',{}).get('file_path',''))" "$INPUT" 2>/dev/null || echo "")"

matched=0
for ext in $SRC_EXTS; do
  if [[ "$FILE_PATH" == *".$ext" ]]; then matched=1; break; fi
done
[ "$matched" = "1" ] || exit 0

cd "$PROJECT_ROOT" || exit 0
bash -c "$FMT_CMD" >/dev/null 2>&1 || true
exit 0
