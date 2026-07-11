#!/usr/bin/env bash
# Live statusline: [<project>] <branch><dirty> | build:X tests:X | N running, M broken/needs-fix
# [| ctx:⚠ <verdict>] [| Kx lesson(s) ready to promote] — the two bracketed suffixes
# only appear when there's something to act on, to keep the steady-state line short.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -f "$PROJECT_ROOT/.claude/harness.env" ] && . "$PROJECT_ROOT/.claude/harness.env"
PROJECT_NAME="${PROJECT_NAME:-project}"

STATUS_FILE="$PROJECT_ROOT/.claude/state/status.json"
TASKS_FILE="$PROJECT_ROOT/.claude/tasks/TASKS.md"
LESSONS_DIR="$PROJECT_ROOT/.claude/memory/lessons"
BUDGET_SCRIPT="$PROJECT_ROOT/.claude/scripts/context-budget.sh"

cd "$PROJECT_ROOT"

branch="$(git symbolic-ref --short -q HEAD || git rev-parse --short HEAD 2>/dev/null || echo "no-git")"
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

# Lessons at/above the promotion threshold (weight >= 3.0) but still status:active —
# these are ready for /learn to promote into a hook, regression check, or CLAUDE.md line.
promotable=0
if [ -d "$LESSONS_DIR" ] && command -v python3 >/dev/null 2>&1; then
  promotable="$(python3 -c "
import glob, re
n = 0
for f in glob.glob('$LESSONS_DIR/[0-9]*.md'):
    text = open(f, encoding='utf-8').read()
    m = re.match(r'^.*?\n---\n(.*?)\n---', text, re.DOTALL)
    if not m:
        continue
    fm = m.group(1)
    status = re.search(r'^status:\s*(\S+)', fm, re.MULTILINE)
    weight = re.search(r'^weight:\s*([\d.]+)', fm, re.MULTILINE)
    if status and weight and status.group(1) == 'active' and float(weight.group(1)) >= 3.0:
        n += 1
print(n)
" 2>/dev/null || echo 0)"
fi
learn_flag=""
if [ "${promotable:-0}" -gt 0 ] 2>/dev/null; then
  learn_flag=" | ${promotable}x lesson(s) ready to promote"
fi

# Context budget verdict — only surfaced when it's not a clean pass; reuses
# context-budget.sh's own verdict rather than recomputing the budget logic here.
ctx_warn=""
if [ -f "$BUDGET_SCRIPT" ]; then
  verdict_line="$(bash "$BUDGET_SCRIPT" 2>/dev/null | grep '^VERDICT:' || true)"
  case "$verdict_line" in
    *"NEAR LIMIT"*) ctx_warn=" | ctx:⚠ NEAR LIMIT" ;;
    *"OVER BUDGET"*) ctx_warn=" | ctx:⚠ OVER BUDGET" ;;
  esac
fi

printf '[%s] %s%s | build:%s tests:%s | %s running, %s broken/needs-fix%s%s\n' \
  "$PROJECT_NAME" "$branch" "$dirty" "$(mark "$build")" "$(mark "$tests")" "$running" "$needsfix_broken" "$ctx_warn" "$learn_flag"
