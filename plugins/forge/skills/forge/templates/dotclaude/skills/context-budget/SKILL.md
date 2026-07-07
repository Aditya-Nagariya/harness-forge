---
name: context-budget
description: "Measure and defend the always-loaded context budget (CLAUDE.md + unscoped rules). A self-improving harness accretes rules and lessons over time; without this regulator it silently bloats until instruction-following degrades. Run periodically, after adding rules, or when CLAUDE.md grows."
allowed-tools: "Bash(bash .claude/scripts/context-budget.sh), Read, Grep, Glob"
---

The regulator for the harness's own context cost. Always-loaded content (CLAUDE.md + every `.claude/rules/*.md` without a `paths:` frontmatter) is paid on **every turn**; instruction-following measurably decays as it grows, and small models degrade fastest — so this must stay small. Path-scoped rules and skills/agents cost nothing until triggered and don't count.

## Steps

1. Run `bash .claude/scripts/context-budget.sh`. It prints each always-loaded file's token estimate, the total, and a PASS / NEAR LIMIT / OVER BUDGET verdict (target ≤1200, hard cap ≤1500).
2. If PASS and nothing is close: report the number and stop. A clean budget needs no work.
3. If NEAR LIMIT or OVER BUDGET, reduce in this order of preference (each keeps the information, just moves its cost off the always-loaded path):
   - **Move detail out of CLAUDE.md** into an on-demand reference (`.claude/HARNESS.md`) or the relevant skill. CLAUDE.md should be a ~25-line index of pointers, not prose. This is almost always the biggest contributor.
   - **Path-scope a rule**: if a rule only matters near certain files, add `paths: ["glob"]` frontmatter so it loads only when Claude reads a matching file.
   - **Fold a rule into a skill or hook**: a procedure belongs in a skill (zero cost until invoked); a mechanically-enforceable rule belongs in a hook (zero context cost, 100% compliance).
   - **Trim wording**: terse lines, no restated rationale, no duplication between CLAUDE.md and a rule.
4. Re-run the script until PASS. Never delete a *rule's substance* to hit the number — relocate it. If you genuinely cannot get under the cap without losing something load-bearing, report that explicitly rather than quietly dropping content.

Wire `bash .claude/scripts/context-budget.sh` into CI so a future rule/lesson addition can't silently blow the budget.
