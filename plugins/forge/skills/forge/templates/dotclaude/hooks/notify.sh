#!/usr/bin/env bash
# Notification hook: desktop notification when Claude needs attention or a
# long-running task finishes. Adapted from dotclaude-main's notify.sh.
# HARNESS_NOTIFY_DRYRUN=1 prints instead of firing a real notification (used by
# hook tests) — same pattern as dotclaude's DOTCLAUDE_NOTIFY_DRYRUN.
set -uo pipefail

INPUT="$(cat)"

MESSAGE="Claude Code needs your attention"
if command -v python3 >/dev/null 2>&1; then
  MESSAGE="$(python3 -c "
import json, sys
d = json.loads(sys.argv[1])
print(d.get('message') or 'Claude Code needs your attention')
" "$INPUT" 2>/dev/null || echo "$MESSAGE")"
fi

if [[ "${HARNESS_NOTIFY_DRYRUN:-0}" == "1" ]]; then
  echo "DRYRUN notify: $MESSAGE"
  exit 0
fi

if command -v osascript >/dev/null 2>&1; then
  osascript -e "display notification \"$MESSAGE\" with title \"Claude Code\"" >/dev/null 2>&1 || true
elif command -v notify-send >/dev/null 2>&1; then
  notify-send "Claude Code" "$MESSAGE" >/dev/null 2>&1 || true
fi

exit 0
