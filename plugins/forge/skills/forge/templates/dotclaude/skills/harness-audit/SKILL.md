---
name: harness-audit
description: "Self-maintenance pass over the .claude/ harness itself: validate every mechanical invariant, detect drift and dead weight, and propose upgrades. Run periodically, after any harness change, or via /loop."
allowed-tools: "Bash(bash .claude/scripts/self-check.sh), Bash(bash .claude/scripts/context-budget.sh), Bash(bash .claude/hooks/tests/run-all.sh), Bash(bash .claude/evals/regressions/run-all.sh), Read, Grep, Glob"
---

The self-maintenance half of the harness: Skip-check → Inventory → Diagnose → Remediate → Update baseline. **Fix-forward rule:** anything mechanically checkable that fails gets fixed in this pass, not just reported; judgment calls get proposed to the user, staged by risk.

## Phase 0 — Skip conditions (check first; decline rather than churn)

Decline to run a full pass, and say why, if any of these hold:
- The latest `memory/decisions.md` entry referencing `harness-audit` is within the last 14 days (avoid re-auditing something just audited).
- `TASKS.md` has an `in_progress`/`running` entry AND `git status` shows uncommitted work touching that feature (mid-feature build — wait for a checkpoint).
- `git status` is clean AND `TASKS.md` has no open entries (nothing to do).

If the user explicitly asked for an audit despite a skip condition, run it anyway — Phase 0 is an anti-churn default, not a hard block.

## Phase 1 — Read the baseline, then check mechanical invariants

Read `references/baseline.md` **first** — it's this project's living record of agreed sources-of-truth, load order, naming conventions, and known gotchas. The method here is general; the baseline grounds each run in what was already decided so you don't re-derive it. When this method and the baseline disagree, the baseline wins.

Run `bash .claude/scripts/self-check.sh` — it verifies JSON validity, agent/skill YAML frontmatter (broken frontmatter silently de-registers an agent until spawn time — lesson 0002), hook exec bits, leftover template placeholders, hook fixtures, regression checks, and the context budget in one pass, exiting nonzero on any failure. Fix whatever it flags, then re-run until clean. Also confirm **wiring completeness** by hand: every hook script referenced in `.claude/settings.json` exists, and every hook script on disk is either wired in settings.json or documented as manual-only.

## Phase 2 — Drift & dead-weight detection

7. **Hook↔fixture coverage**: every deterministic PreToolUse gate hook has ≥1 block-path fixture and ≥1 allow-path fixture (a gate whose block path is untested is the dangerous kind — its failure mode is "silently allow" — see lesson 0001).
8. **CLAUDE.md accuracy**: every file/command CLAUDE.md names still exists (grep its inline paths against the tree); every hook it describes matches the actual settings.json wiring. If a referenced path is gone, **comment out the line** (`<!-- broken ref (was: <path>) -->`) rather than deleting it — preserves the "someone meant something here" signal for the user to resolve.
9. **Lesson store health**: INDEX.md lines match the actual files in `.claude/memory/lessons/` one-to-one; any lesson at weight ≥3.0 not yet promoted, or ≤0 not yet retired, is flagged for `/learn`'s promotion step.
10. **Dead weight, with memory.** Rules/skills/agents nothing references and no session has used — candidates for retirement (propose, don't delete unilaterally). Before proposing, check `memory/decisions.md` for a prior `[keep] <item> — <reason> — <date>` entry for this exact candidate — if found, don't re-ask. When the user says "keep" to a proposal, record that line so the next audit doesn't re-propose it.
11. **Status truthfulness**: `status.json` task statuses match `TASKS.md`; `TASKS.md` items marked `completed` exist in `ARCHIVE.md` with a verification line.
12. **Plans archival**: any `plans/<slug>` entry whose matching `TASKS.md`/`ARCHIVE.md` status is completed/shipped but hasn't been moved to `plans/archive/` gets flagged — this is the exact failure mode a plan-lifecycle system silently regresses into if nothing checks it.
13. **Issues-solved numbering integrity**: cross-check `issues-solved/INDEX.md`'s claimed IDs against an actual `ls issues-solved/` — (a) any `NNNN-*.md` file on disk with no `INDEX.md` row is a lint failure (it either needs an index row or needs deleting); (b) any two files sharing the same `NNNN` is a lint failure — if a later entry corrects an earlier one, the earlier file must get an explicit `⚠️ Superseded by NNNN — see NNNN` cross-link (in both directions), never a silent duplicate-numbered orphan.
14. **State-file seams**: for every file written under `state/` by a hook or workflow, grep the template tree for a reader. A write-only store is a disconnection, not dead weight — propose either wiring a consumer or removing the write. (Concrete standing check: `elevate.js` documents that its caller should append `result.routing` to `state/routing-stats.json` after each run — if that file exists, read it and report which step patterns chronically escalate to the stronger model, since those should be routed there directly next time instead of retried on the small model.)

## Phase 3 — Report & propose

Bucket every proposed change by risk, each with **change · reason · risk · rollback**:
- **(A) Quick wins** — safe, mechanical (stale/backup file removal, a broken-ref comment-out already applied in Phase 2).
- **(B) Wiring** — connecting a disconnected seam (Phase 2 item 14) — usually the highest-value bucket.
- **(C) Structural** — consolidating overlapping stores or reworking a convention — the highest-risk bucket, needs explicit user sign-off before touching anything.

Execute (A) inline per the fix-forward rule. Present (B) and (C) as proposals, at most 3 total ranked by expected value, and **only when tied to observed evidence** (a ledger signature, a failed check, a documented near-miss) — scaffold changes without a demonstrated failure mode are churn, not maintenance.

Close with one line: `N/N checks passed | M fixed inline | K flagged`. If everything passes and nothing is flagged, say exactly that and stop.

## Phase 4 — Update the baseline

Append what changed this run to `references/baseline.md`'s change log (dated, one line) — new wiring, a newly-decided convention, a gotcha discovered this run. This is what makes the baseline a living document instead of a report that gets thrown away after every invocation.
