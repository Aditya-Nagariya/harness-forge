#!/usr/bin/env bash
# PreToolUse (Write|Edit) hook: hard-gates the first real source-code edit of a
# session behind two conditions — (a) /loop is not overdue, (b) a SkillSeek
# capability search happened this session (or SkillSeek isn't installed, in
# which case this condition is treated as satisfied — fail open on an optional
# companion tool). This is the deterministic replacement for an advisory
# "please run /loop" nudge: hooks get ~100% compliance, prose nudges don't.
#
# Never gates paths under .claude/ — /loop's own first action (/learn writing a
# lesson file) must never trip this gate before /loop can satisfy it. Fails
# open (exit 0) if python3 is missing: this is a capability-quality gate, not a
# security boundary, so a missing interpreter should not block all editing.
set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Caller env wins over harness.env (deterministic fixtures); harness.env wins over defaults.
_PRE_STATE_DIR="${FORGE_STATE_DIR:-}"
_PRE_OVERDUE="${LOOP_OVERDUE_HOURS:-}"
_PRE_SKILLSEEK_INDEX="${FORGE_SKILLSEEK_INDEX:-}"
[ -f "$PROJECT_ROOT/.claude/harness.env" ] && . "$PROJECT_ROOT/.claude/harness.env"
STATE_DIR="${_PRE_STATE_DIR:-$PROJECT_ROOT/.claude/state}"
LOOP_OVERDUE_HOURS="${_PRE_OVERDUE:-${LOOP_OVERDUE_HOURS:-24}}"
SKILLSEEK_INDEX="${_PRE_SKILLSEEK_INDEX:-$HOME/.claude/SKILLS-INDEX.json}"

if ! command -v python3 >/dev/null 2>&1; then
  exit 0
fi

INPUT="$(cat)"
FILE_PATH="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d.get('tool_input',{}).get('file_path',''))" "$INPUT" 2>/dev/null || echo "")"
[ -n "$FILE_PATH" ] || exit 0

# Anti-deadlock: never gate anything under .claude/ (memory, tasks, state, hooks...).
case "$FILE_PATH" in
  */.claude/*) exit 0 ;;
esac

GATE_FLAG="$STATE_DIR/.gate-checked-this-session"
if [ -f "$GATE_FLAG" ]; then
  exit 0
fi

SEARCH_FLAG="$STATE_DIR/.skillseek-used-this-session"
LAST_LOOP_FILE="$STATE_DIR/last-loop-run.json"

loop_overdue="true"
if [ -f "$LAST_LOOP_FILE" ]; then
  loop_overdue="$(python3 -c "
import json, sys
from datetime import datetime, timezone
try:
    last = json.load(open(sys.argv[1]))['last_run']
    last_dt = datetime.strptime(last, '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc)
    hours = (datetime.now(timezone.utc) - last_dt).total_seconds() / 3600
    print('true' if hours > float(sys.argv[2]) else 'false')
except Exception:
    print('true')
" "$LAST_LOOP_FILE" "$LOOP_OVERDUE_HOURS" 2>/dev/null || echo "true")"
fi

skillseek_installed="false"
[ -f "$SKILLSEEK_INDEX" ] && skillseek_installed="true"

skillseek_satisfied="true"
if [ "$skillseek_installed" = "true" ] && [ ! -f "$SEARCH_FLAG" ]; then
  skillseek_satisfied="false"
fi

if [ "$loop_overdue" = "false" ] && [ "$skillseek_satisfied" = "true" ]; then
  mkdir -p "$STATE_DIR"
  touch "$GATE_FLAG"
  exit 0
fi

reasons=()
[ "$loop_overdue" = "true" ] && reasons+=("run /loop first (self-healing maintenance is overdue)")
[ "$skillseek_satisfied" = "false" ] && reasons+=("call the skill_search MCP tool first (SkillSeek is installed but hasn't been used this session — you may be missing a relevant installed skill)")

reason_text="$(IFS='; '; echo "${reasons[*]}")"
python3 -c "
import json, sys
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'permissionDecision': 'deny', 'permissionDecisionReason': sys.argv[1]}}))
" "Before editing source, $reason_text. This check runs once per session; it will not block again after you resolve it." 2>/dev/null || echo "BLOCKED: $reason_text" >&2
exit 2
