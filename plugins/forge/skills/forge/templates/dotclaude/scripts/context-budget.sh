#!/usr/bin/env bash
# context-budget: measure the ALWAYS-LOADED context footprint (CLAUDE.md + every
# .claude/rules/*.md WITHOUT a `paths:` frontmatter key) and compare to the budget.
# Path-scoped rules and skills/agents cost nothing until triggered, so they are
# excluded. Exit 1 if over the hard cap — usable as a CI gate and by /context-budget.
#
# Budgets (chars/4 token estimate): target <= CAP_TARGET, hard cap <= CAP_HARD.
set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

CAP_TARGET="${CAP_TARGET:-1200}"
CAP_HARD="${CAP_HARD:-1500}"

python3 - "$CAP_TARGET" "$CAP_HARD" <<'PY'
import glob, os, re, sys

cap_target, cap_hard = int(sys.argv[1]), int(sys.argv[2])

def toks(path):
    return (len(open(path, encoding="utf-8").read()) + 3) // 4

def is_path_scoped(path):
    head = "".join(open(path, encoding="utf-8").readlines()[:8])
    m = re.match(r"^---\n(.*?)\n---", head, re.DOTALL)
    return bool(m and re.search(r"^paths:", m.group(1), re.MULTILINE))

always = []
for p in (["CLAUDE.md"] + sorted(glob.glob(".claude/rules/*.md"))):
    if not os.path.exists(p):
        continue
    if p.endswith("README.md"):
        continue
    if p.startswith(".claude/rules/") and is_path_scoped(p):
        continue
    always.append((toks(p), p))

total = sum(t for t, _ in always)
always.sort(reverse=True)

print("Always-loaded context (CLAUDE.md + unscoped rules):")
for t, p in always:
    print(f"  {t:>5} tok  {p}")
print(f"  {'-'*30}")
print(f"  {total:>5} tok  TOTAL   (target <= {cap_target}, hard cap <= {cap_hard})")

if total <= cap_target:
    print(f"VERDICT: PASS ({total} <= {cap_target})")
    sys.exit(0)
elif total <= cap_hard:
    print(f"VERDICT: NEAR LIMIT ({total}) — trim the largest file, or move detail into a skill / on-demand doc, or path-scope a rule.")
    sys.exit(0)
else:
    print(f"VERDICT: OVER BUDGET ({total} > {cap_hard}) — the biggest contributor above must shrink. CLAUDE.md should be a ~25-line index; move subsystem prose into skills/guides that load on demand. Rules that only matter near certain files get a `paths:` frontmatter.")
    sys.exit(1)
PY
