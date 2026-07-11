#!/usr/bin/env bash
# PostToolUse hook (Write|Edit): keep an `updated: YYYY-MM-DD` frontmatter field
# honest without relying on a model to remember to bump it by hand. Only touches
# a small allowlist of tracked files, and only the frontmatter block (first
# `---`...`---`) — the rest of the file is untouched. Fully idempotent: no-ops if
# there's no frontmatter, no `updated:` key, or the date already matches today.
set -uo pipefail

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
[ -f "$FILE_PATH" ] || exit 0

FNAME="$(basename "$FILE_PATH")"
case "$FNAME" in
  TASKS.md|ARCHIVE.md|CLAUDE.md|decisions.md) ;;
  [0-9][0-9][0-9][0-9]-*.md)
    # Numbered lesson/issue files (memory/lessons/NNNN-*.md, issues-solved/NNNN-*.md)
    case "$FILE_PATH" in
      */memory/lessons/*|*/issues-solved/*) ;;
      *) exit 0 ;;
    esac
    ;;
  *) exit 0 ;;
esac

python3 -c "
import re, sys
from datetime import datetime, timezone

path = sys.argv[1]
today = datetime.now(timezone.utc).strftime('%Y-%m-%d')

with open(path, encoding='utf-8') as f:
    s = f.read()

m = re.match(r'^(---\n)(.*?)(\n---\n)', s, flags=re.S)
if not m:
    sys.exit(0)

fm = m.group(2)
new_fm, n = re.subn(r'(?m)^(updated:\s*)\d{4}-\d{2}-\d{2}', r'\g<1>' + today, fm, count=1)
if n == 0 or new_fm == fm:
    sys.exit(0)

new_s = s[:m.start(2)] + new_fm + s[m.end(2):]
with open(path, 'w', encoding='utf-8') as f:
    f.write(new_s)
" "$FILE_PATH"

exit 0
