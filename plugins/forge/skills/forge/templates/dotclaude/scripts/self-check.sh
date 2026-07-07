#!/usr/bin/env bash
# self-check: verify this project's harness mechanical invariants. Shipped into
# every project so it can self-validate without the forge plugin present.
# Checks: JSON validity, agent/skill YAML frontmatter, hook exec bits, leftover
# {{PLACEHOLDER}}s, hook fixtures, regression checks, context budget.
# Exit nonzero on any failure. Used by /harness-audit and CI.
set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

fail=0
bad(){ echo "FAIL: $1"; fail=1; }
note(){ echo "ok: $1"; }

# 1. JSON validity
while IFS= read -r f; do
  python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$f" 2>/dev/null || bad "invalid JSON: $f"
done < <(find .claude -name "*.json" -not -path "*/worktrees/*" 2>/dev/null)
note "JSON"

# 2. YAML frontmatter (skip with warning if pyyaml absent)
if python3 -c "import yaml" 2>/dev/null; then
  python3 - <<'PY' || bad "frontmatter"
import re, glob, sys, yaml
bad = False
for f in sorted(glob.glob(".claude/agents/*.md") + glob.glob(".claude/skills/*/SKILL.md")):
    m = re.match(r"^---\n(.*?)\n---\n", open(f, encoding="utf-8").read(), re.DOTALL)
    if not m:
        print(f"  no frontmatter: {f}"); bad = True; continue
    try:
        d = yaml.safe_load(m.group(1))
        assert isinstance(d.get("name"), str) and isinstance(d.get("description"), str)
    except Exception as e:
        print(f"  broken frontmatter: {f}: {e}"); bad = True
sys.exit(1 if bad else 0)
PY
  note "frontmatter"
else
  echo "WARN: pyyaml not installed — frontmatter check skipped"
fi

# 3. Executable bits
while IFS= read -r f; do
  [ -x "$f" ] || bad "not executable: $f"
done < <(find .claude/hooks .claude/scripts .claude/evals -name "*.sh" 2>/dev/null; ls .claude/statusline.sh 2>/dev/null)
note "exec bits"

# 4. Leftover placeholders (installed files should have none; harness.env excepted)
if grep -rln "{{[A-Z_]*}}" .claude --include="*.sh" --include="*.json" --include="*.md" --exclude-dir=memory --exclude-dir=issues-solved 2>/dev/null \
     | grep -v "\.forge-new$" | grep -v "harness.env" | grep -v "self-check.sh" | grep -q .; then
  grep -rln "{{[A-Z_]*}}" .claude --include="*.sh" --include="*.json" --include="*.md" --exclude-dir=memory --exclude-dir=issues-solved 2>/dev/null \
     | grep -v "\.forge-new$" | grep -v "harness.env" | grep -v "self-check.sh" | while read -r f; do echo "  placeholder in: $f"; done
  bad "unsubstituted placeholders"
fi
note "placeholders"

# 5. Hook fixtures
if [ -f .claude/hooks/tests/run-all.sh ]; then
  bash .claude/hooks/tests/run-all.sh >/tmp/self-check-hooks.log 2>&1 \
    && note "hook fixtures ($(grep -o 'RESULT: .*' /tmp/self-check-hooks.log))" \
    || { bad "hook fixtures"; tail -4 /tmp/self-check-hooks.log; }
fi

# 6. Regression checks
if [ -f .claude/evals/regressions/run-all.sh ]; then
  bash .claude/evals/regressions/run-all.sh >/tmp/self-check-regr.log 2>&1 \
    && note "regressions ($(grep -o 'REGRESSIONS: .*' /tmp/self-check-regr.log))" \
    || { bad "regression checks"; tail -4 /tmp/self-check-regr.log; }
fi

# 7. Context budget
if [ -f .claude/scripts/context-budget.sh ]; then
  bash .claude/scripts/context-budget.sh >/tmp/self-check-budget.log 2>&1 \
    && note "context budget ($(grep -o 'VERDICT: .*' /tmp/self-check-budget.log))" \
    || { bad "context budget over hard cap"; grep -o 'VERDICT: .*' /tmp/self-check-budget.log; }
fi

echo ""
[ "$fail" -eq 0 ] && echo "SELF-CHECK: all invariants pass" || echo "SELF-CHECK: FAILURES FOUND"
exit "$fail"
