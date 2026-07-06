---
name: harness-audit
description: "Self-maintenance pass over the .claude/ harness itself: validate every mechanical invariant (JSON, YAML frontmatter, exec bits, hook tests, regression checks), detect drift and dead weight, and propose upgrades. Run periodically, after any harness change, or via /loop."
allowed-tools: "Bash(bash .claude/hooks/tests/run-all.sh), Bash(bash .claude/evals/regressions/run-all.sh), Read, Grep, Glob"
---

The self-maintenance half of the harness. Phased like the SENA-main harness-audit methodology (Inventory → Diagnose → Remediate → Update baseline), with the mechanical checks made deterministic. **Fix-forward rule:** anything mechanically checkable that fails gets fixed in this pass, not just reported; judgment calls get proposed to the user.

## Phase 1 — Mechanical invariants (all must pass; fix what fails)

1. **JSON validity**: every `.claude/**/*.json` parses (`python3 -c "import json; json.load(open(f))"` over a glob).
2. **YAML frontmatter validity**: every `.claude/agents/*.md` and `.claude/skills/*/SKILL.md` frontmatter parses via `yaml.safe_load` with `name` + `description` present as strings (a documented silent-breakage class: broken frontmatter de-registers the agent with no error until spawn time — see lesson 0002).
3. **Executable bits**: every `.claude/hooks/*.sh`, `.claude/hooks/tests/run-all.sh`, `.claude/scripts/*.sh`, `.claude/statusline.sh` is executable.
4. **Hook tests green**: `bash .claude/hooks/tests/run-all.sh` exits 0.
5. **Regression checks green**: `bash .claude/evals/regressions/run-all.sh` exits 0.
6. **Wiring completeness**: every hook script referenced in `.claude/settings.json` exists; every hook script on disk is either wired in settings.json or documented as manual-only.

## Phase 2 — Drift & dead-weight detection

7. **Hook↔fixture coverage**: every deterministic PreToolUse gate hook has ≥1 block-path fixture and ≥1 allow-path fixture (a gate whose block path is untested is the dangerous kind — its failure mode is "silently allow" — see lesson 0001).
8. **CLAUDE.md accuracy**: every file/command CLAUDE.md names still exists (grep its inline paths against the tree); every hook it describes matches the actual settings.json wiring.
9. **Lesson store health**: INDEX.md lines match the actual files in `.claude/memory/lessons/` one-to-one; any lesson at weight ≥3.0 not yet promoted, or ≤0 not yet retired, is flagged for `/learn`'s promotion step.
10. **Dead weight**: rules/skills/agents nothing references and no session has used — candidates for retirement (propose, don't delete unilaterally).
11. **Status truthfulness**: `status.json` task statuses match `TASKS.md`; `TASKS.md` items marked `completed` exist in `ARCHIVE.md` with a verification line.

## Phase 3 — Report & propose

Output: a table of check → pass/fixed/flagged, then at most 3 proposed upgrades ranked by expected value. **Propose a harness change only when tied to observed evidence** (a ledger signature, a failed check, a documented near-miss) — scaffold changes without a demonstrated failure mode are churn, not maintenance. If everything passes and nothing is flagged, say exactly that and stop; a clean audit needs no invented work.
