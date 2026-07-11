#!/usr/bin/env bash
# SessionEnd hook: fires exactly once at true session end (/exit), unlike Stop
# (which fires every turn) — the only reliable place for lightweight final
# housekeeping. SessionEnd has no decision control and nothing further will be
# shown to the user this session, so this is fire-and-forget: append a durable
# "session closed" snapshot to activity-log.md so the *next* session (or a human
# skimming the log) can see what state things were left in.
#
# Keep this cheap and synchronous — do not background work here. A prior design
# that backgrounded end-of-session work discovered that process-tree teardown on
# /exit can kill a detached child mid-run with no error, silently losing the work
# (see .claude/memory/lessons/ if that class of bug recurs). This hook does none
# of that: it's a few git/grep calls and one file append, done inline.
set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT" || exit 0

cat >/dev/null 2>&1 || true  # consume stdin; this hook doesn't need any input fields

LOG_FILE=".claude/memory/activity-log.md"
[ -f "$LOG_FILE" ] || exit 0

BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'no-branch')"
COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo 'no-commit')"
DIRTY="clean"
if ! { git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null; }; then
  DIRTY="dirty"
fi

RUNNING=0
if [ -f ".claude/tasks/TASKS.md" ]; then
  RUNNING="$(grep -c '^Status: running' .claude/tasks/TASKS.md 2>/dev/null)" || RUNNING=0
fi

TODAY="$(date -u +%Y-%m-%d)"
echo "[$TODAY] [hook:session-end] — session closed — branch=$BRANCH commit=$COMMIT working_tree=$DIRTY running_tasks=$RUNNING" >> "$LOG_FILE"

exit 0
