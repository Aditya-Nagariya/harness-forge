#!/usr/bin/env bash
# PreCompact hook: fires before context compaction, which otherwise erases
# trailing turns silently. Appends a durable resume marker (branch, commit,
# working-tree state, open-task count) to activity-log.md so a compacted
# session can still tell what was in flight. Idempotent within a day (a second
# compaction on the same day is a no-op) so it can fire many times without
# spamming duplicate lines. Never blocks compaction — this is a side note, not
# a gate.
set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT" || exit 0

cat >/dev/null 2>&1 || true  # consume stdin; this hook doesn't need any input fields

LOG_FILE=".claude/memory/activity-log.md"
[ -f "$LOG_FILE" ] || exit 0

TODAY="$(date -u +%Y-%m-%d)"

if grep -q "^\[$TODAY\] \[hook:pre-compact\]" "$LOG_FILE" 2>/dev/null; then
  exit 0
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'no-branch')"
COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo 'no-commit')"
DIRTY="clean"
if ! { git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null; }; then
  DIRTY="dirty"
fi

OPEN_TASKS=0
if [ -f ".claude/tasks/TASKS.md" ]; then
  OPEN_TASKS="$(grep -cE '^Status: (pending|running|needs-fix|broken|upgrading)' .claude/tasks/TASKS.md 2>/dev/null)" || OPEN_TASKS=0
fi

echo "[$TODAY] [hook:pre-compact] — compaction snapshot — branch=$BRANCH commit=$COMMIT working_tree=$DIRTY open_tasks=$OPEN_TASKS; resume order: CLAUDE.md -> .claude/tasks/TASKS.md" >> "$LOG_FILE"

exit 0
