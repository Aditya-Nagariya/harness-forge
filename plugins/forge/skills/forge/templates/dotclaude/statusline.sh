#!/usr/bin/env bash
# Live statusline: [<project>] <branch><dirty> | build:X tests:X | N running, M broken/needs-fix
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -f "$PROJECT_ROOT/.claude/harness.env" ] && . "$PROJECT_ROOT/.claude/harness.env"
PROJECT_NAME="${PROJECT_NAME:-project}"

STATUS_FILE="$PROJECT_ROOT/.claude/state/status.json"
TASKS_FILE="$PROJECT_ROOT/.claude/tasks/TASKS.md"

cd "$PROJECT_ROOT"

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "no-git")"
dirty=""
if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
  dirty="*"
fi

mark() {
  case "$1" in
    pass) echo "✓" ;;
    fail) echo "✗" ;;
    *) echo "?" ;;
  esac
}

build="unknown"
tests="unknown"
if [ -f "$STATUS_FILE" ] && command -v python3 >/dev/null 2>&1; then
  build="$(python3 -c "import json; print(json.load(open('$STATUS_FILE')).get('health',{}).get('build','unknown'))" 2>/dev/null || echo unknown)"
  tests="$(python3 -c "import json; print(json.load(open('$STATUS_FILE')).get('health',{}).get('tests','unknown'))" 2>/dev/null || echo unknown)"
fi

running=0
needsfix_broken=0
if [ -f "$TASKS_FILE" ]; then
  running=$(grep -c '^Status: running' "$TASKS_FILE" 2>/dev/null) || running=0
  needsfix_broken=$(grep -cE '^Status: (needs-fix|broken)' "$TASKS_FILE" 2>/dev/null) || needsfix_broken=0
fi

printf '[%s] %s%s | build:%s tests:%s | %s running, %s broken/needs-fix\n' \
  "$PROJECT_NAME" "$branch" "$dirty" "$(mark "$build")" "$(mark "$tests")" "$running" "$needsfix_broken"
