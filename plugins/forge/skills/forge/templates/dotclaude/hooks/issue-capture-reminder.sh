#!/usr/bin/env bash
# PostToolUse hook (Write|Edit): detects a "debug signature" — the same file
# edited 3+ times in one session — and nudges toward capturing an issues-solved
# entry. This is a DIFFERENT signal from capture-failure.sh, which only fires on
# actual tool errors: this one catches pure edit-churn (iterative trial-and-error
# via successful edits that never technically failed a tool call — e.g. logic
# that only breaks at runtime/test time, discovered and fixed over several
# passes). Silent below the threshold; fires once per file per session.
#
# State: .claude/state/edit-counts.txt, format <file_path>|<count>|<reminded-flag>.
# Reset heuristic: state file older than 2h = treat as a new session, wipe it.
set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE_FILE="$PROJECT_ROOT/.claude/state/edit-counts.txt"
THRESHOLD=3
RESET_AFTER_SECONDS=7200

INPUT="$(cat)"

if ! command -v python3 >/dev/null 2>&1; then
  exit 0
fi

FILE_PATH="$(python3 -c "
import json, sys
d = json.loads(sys.argv[1])
print((d.get('tool_response') or {}).get('filePath') or (d.get('tool_input') or {}).get('file_path') or '')
" "$INPUT" 2>/dev/null || echo "")"

[ -n "$FILE_PATH" ] || exit 0

case "$FILE_PATH" in
  *.py|*.ts|*.tsx|*.js|*.jsx|*.html|*.css|*.sh|*.go|*.rs|*.java|*.rb|*.php|*.c|*.cpp|*.cs) ;;
  *) exit 0 ;;
esac
case "$FILE_PATH" in
  */.claude/issues-solved/*|*/.claude/hooks/*|*/.claude/state/*) exit 0 ;;
esac

mkdir -p "$(dirname "$STATE_FILE")"
touch "$STATE_FILE"

# Staleness reset: GNU stat then BSD/macOS stat fallback.
NOW="$(date +%s)"
MTIME="$(stat -c %Y "$STATE_FILE" 2>/dev/null || stat -f %m "$STATE_FILE" 2>/dev/null || echo "$NOW")"
if [ $((NOW - MTIME)) -gt "$RESET_AFTER_SECONDS" ]; then
  : > "$STATE_FILE"
fi

PREV_LINE="$(grep -F "${FILE_PATH}|" "$STATE_FILE" 2>/dev/null | head -1)"
PREV_COUNT=0
REMINDED=0
if [ -n "$PREV_LINE" ]; then
  PREV_COUNT="$(printf '%s' "$PREV_LINE" | cut -d'|' -f2)"
  REMINDED="$(printf '%s' "$PREV_LINE" | cut -d'|' -f3)"
fi
NEW_COUNT=$((PREV_COUNT + 1))

TMP_FILE="${STATE_FILE}.tmp"
grep -vF "${FILE_PATH}|" "$STATE_FILE" > "$TMP_FILE" 2>/dev/null || true
echo "${FILE_PATH}|${NEW_COUNT}|${REMINDED}" >> "$TMP_FILE"
mv "$TMP_FILE" "$STATE_FILE"

if [ "$NEW_COUNT" -ge "$THRESHOLD" ] && [ "$REMINDED" != "1" ]; then
  python3 -c "
import sys
path, target = sys.argv[1], sys.argv[2]
lines = open(path, encoding='utf-8').read().splitlines()
out = []
for line in lines:
    parts = line.split('|')
    if len(parts) == 3 and parts[0] == target:
        out.append(parts[0] + '|' + parts[1] + '|1')
    else:
        out.append(line)
open(path, 'w', encoding='utf-8').write('\n'.join(out) + '\n')
" "$STATE_FILE" "$FILE_PATH"

  python3 -c "
import json, sys
msg = ('File ' + sys.argv[1] + ' edited ' + sys.argv[2] + ' times this session — debug signature detected. '
       'If you solved a non-trivial bug, capture it: copy .claude/issues-solved/TEMPLATE.md to NNNN-slug.md, '
       'fill symptom/root_cause/fix/failed_attempts, prepend a row to INDEX.md. Check INDEX.md first in case it is already logged.')
print(json.dumps({'systemMessage': msg}))
" "$FILE_PATH" "$NEW_COUNT"
fi

exit 0
