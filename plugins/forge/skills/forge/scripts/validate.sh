#!/usr/bin/env bash
# forge validate: verify an installed harness's mechanical invariants.
# Usage: validate.sh --target DIR
# Checks: JSON validity, YAML frontmatter, exec bits, leftover {{PLACEHOLDER}}s,
# hook test fixtures, regression checks. Exit nonzero on any failure.
set -uo pipefail

TARGET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done
if [ -z "$TARGET" ] || [ ! -d "$TARGET/.claude" ]; then
  echo "usage: validate.sh --target DIR (dir must contain .claude/)" >&2
  exit 1
fi

fail=0
note() { echo "$1"; }
bad()  { echo "FAIL: $1"; fail=1; }

cd "$TARGET"

# 1. JSON validity
while IFS= read -r f; do
  if ! python3 -c "import json; json.load(open('$f'))" 2>/dev/null; then
    bad "invalid JSON: $f"
  fi
done < <(find .claude -name "*.json" -not -path "*/worktrees/*")
note "checked JSON files"

# 2. YAML frontmatter (skip with warning if pyyaml missing)
if python3 -c "import yaml" 2>/dev/null; then
  if ! python3 - <<'PY'
import re, glob, sys, yaml
failed = False
for f in sorted(glob.glob(".claude/agents/*.md") + glob.glob(".claude/skills/*/SKILL.md")):
    content = open(f, encoding="utf-8").read()
    m = re.match(r"^---\n(.*?)\n---\n", content, re.DOTALL)
    if not m:
        print(f"no frontmatter: {f}"); failed = True; continue
    try:
        d = yaml.safe_load(m.group(1))
        assert isinstance(d, dict) and isinstance(d.get("name"), str) and isinstance(d.get("description"), str)
    except Exception as e:
        print(f"broken frontmatter: {f}: {e}"); failed = True
sys.exit(1 if failed else 0)
PY
  then
    bad "frontmatter validation"
  fi
  note "checked agent/skill frontmatter"
else
  note "WARN: pyyaml not installed — frontmatter check skipped (pip3 install pyyaml)"
fi

# 3. Executable bits
while IFS= read -r f; do
  [ -x "$f" ] || bad "not executable: $f"
done < <(find .claude/hooks .claude/scripts .claude/evals -name "*.sh" 2>/dev/null; ls .claude/statusline.sh 2>/dev/null)
note "checked executable bits"

# 4. Leftover placeholders in installed (non-template) files
if grep -rn "{{[A-Z_]*}}" .claude --include="*.sh" --include="*.json" --include="*.md" \
     --exclude="harness.env" --exclude="self-check.sh" --exclude-dir=memory --exclude-dir=issues-solved -l 2>/dev/null | grep -v "\.forge-new$" | head -5 | grep -q .; then
  grep -rn "{{[A-Z_]*}}" .claude --include="*.sh" --include="*.json" --include="*.md" --exclude="harness.env" --exclude="self-check.sh" --exclude-dir=memory --exclude-dir=issues-solved -l | grep -v "\.forge-new$" | while read -r f; do
    bad "unsubstituted placeholder in: $f"
  done
  fail=1
fi
note "checked for leftover placeholders"

# 5. Hook fixtures
if [ -f .claude/hooks/tests/run-all.sh ]; then
  if ! bash .claude/hooks/tests/run-all.sh >/tmp/forge-validate-hooks.log 2>&1; then
    bad "hook fixtures (see /tmp/forge-validate-hooks.log)"
    tail -5 /tmp/forge-validate-hooks.log
  else
    note "hook fixtures: $(grep -o 'RESULT: .*' /tmp/forge-validate-hooks.log)"
  fi
fi

# 6. Regression checks
if [ -f .claude/evals/regressions/run-all.sh ]; then
  if ! bash .claude/evals/regressions/run-all.sh >/tmp/forge-validate-regr.log 2>&1; then
    bad "regression checks (see /tmp/forge-validate-regr.log)"
    tail -5 /tmp/forge-validate-regr.log
  else
    note "regressions: $(grep -o 'REGRESSIONS: .*' /tmp/forge-validate-regr.log)"
  fi
fi

if [ "$fail" -eq 0 ]; then
  echo "VALIDATE: all checks passed"
else
  echo "VALIDATE: FAILURES FOUND"
fi
exit "$fail"
