#!/usr/bin/env bash
# Regression check for issues-solved 0001 / lesson 0003: every agent/skill YAML
# frontmatter must parse with name+description as strings. The original failure
# was silent (broken YAML -> agent de-registered with no error until spawn time).
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

python3 - <<'PY'
import re, glob, sys
try:
    import yaml
except ImportError:
    print("pyyaml not installed - cannot verify frontmatter; failing closed")
    sys.exit(1)

failed = False
files = sorted(glob.glob(".claude/agents/*.md") + glob.glob(".claude/skills/*/SKILL.md"))
if not files:
    print("no agent/skill files found - suspicious for this repo")
    sys.exit(1)
for f in files:
    content = open(f, encoding="utf-8").read()
    m = re.match(r"^---\n(.*?)\n---\n", content, re.DOTALL)
    if not m:
        print(f"{f}: no frontmatter block")
        failed = True
        continue
    try:
        d = yaml.safe_load(m.group(1))
        assert isinstance(d, dict), "frontmatter not a mapping"
        assert isinstance(d.get("name"), str) and d["name"], "missing/invalid name"
        assert isinstance(d.get("description"), str) and d["description"], "missing/invalid description"
    except Exception as e:
        print(f"{f}: {e}")
        failed = True
sys.exit(1 if failed else 0)
PY
