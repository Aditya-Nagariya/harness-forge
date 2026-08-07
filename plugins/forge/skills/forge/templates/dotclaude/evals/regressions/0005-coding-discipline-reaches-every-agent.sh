#!/usr/bin/env bash
# Regression check: the coding-discipline house rules (ROADMAP R12) must reach EVERY
# isolated agent. These agents cannot see .claude/rules/*.md — they only get the
# {{HOUSE_RULES}} substitution — so if a future edit moves this content into a rules
# file, renames the marker, or drops {{HOUSE_RULES}} from an agent, that agent silently
# loses the rules with no other symptom. This check is the mechanical replacement for
# "remember to keep six copies in sync."
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

MARKER="## Coding discipline"
AGENTS="small-executor bug-fixer code-reviewer small-verifier security-reviewer silent-failure-hunter"

failed=0
for name in $AGENTS; do
  f=".claude/agents/${name}.md"
  if [ ! -f "$f" ]; then
    echo "missing agent file: $f"
    failed=1
    continue
  fi
  if ! grep -qF "$MARKER" "$f"; then
    echo "$f: no '$MARKER' section — this agent is not receiving the R12 house rules"
    failed=1
  fi
done

# Both halves must be present, not just the heading.
for phrase in "Think before coding" "Surgical changes"; do
  if ! grep -qF "$phrase" ".claude/agents/small-executor.md"; then
    echo "small-executor.md: missing '$phrase' — the injected block is incomplete"
    failed=1
  fi
done

exit $failed
