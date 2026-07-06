---
name: learn
description: "Convert this session's failures and user corrections into durable per-file lessons in .claude/memory/lessons/, following the evidence-backed write policy (retrieve-similar-first, delta updates, vote lifecycle, hook promotion). Run at the end of any session that contained a correction or a repeated failure."
---

The continuous-learning half of the self-healing loop. The raw signal comes from `.claude/state/failure-ledger.jsonl` (written automatically by `capture-failure.sh`) and from user corrections in this session's conversation. This skill's design follows specific published findings — keep these properties intact when executing it:

- **External evidence only.** A lesson must quote a concrete artifact: a verbatim error message, a failing command's output, or the user's actual correction. If there is no external evidence, do not write a lesson — model self-judgment is not a valid trigger (intrinsic self-correction demonstrably degrades performance; Reflexion-class gains come from evaluator-grounded reflections).
- **Retrieve before writing.** Before adding anything, grep `.claude/memory/lessons/INDEX.md` and the lesson files for similar content, then choose one of: **ADD** (genuinely new), **UPDATE** (same lesson, better wording/trigger), **UPVOTE** (+1.0 weight — the lesson exists and was confirmed again), **DOWNVOTE** (−1.0 — the failure recurred *despite* the lesson existing, meaning the lesson isn't working as written; rewrite its trigger or rule). Never blind-append a near-duplicate.
- **Delta updates only.** Edit individual lesson files and individual INDEX lines. Never rewrite INDEX.md or a lesson file wholesale from memory — full LLM rewrites are the documented cause of "context collapse" in evolving-context systems.
- **Lifecycle:** new lesson starts at weight 1.0 (0.5 if proactive rather than correction-driven). At weight ≥ 3.0, **promote**: if the rule is mechanically checkable, its terminal form is a *hook* (with test fixtures) or a *regression check* in `.claude/evals/regressions/` — not more prose (hooks get ~100% compliance; advisory rules get 70–90% and dilute each other). If judgment-based, add one line to CLAUDE.md and mark the lesson `status: promoted`. At weight ≤ 0, mark `status: retired` (keep the file; set `superseded_by:` if replaced — invalidate, don't delete).

## Steps

1. Read `.claude/state/failure-ledger.jsonl` (if present). Group by `signature`; any signature with ≥2 occurrences is a lesson candidate.
2. Scan this session's conversation for user corrections (explicit "no, do X", reverted work, repeated re-asks) and for failure→success contrast pairs (the strongest lessons state what *changed* between the failed and successful attempt).
3. For each candidate, apply the retrieve-before-writing policy above (ADD/UPDATE/UPVOTE/DOWNVOTE).
4. For ADDs: create `.claude/memory/lessons/NNNN-short-slug.md` (next free number) in the exact format of the existing files — first line `Summary: <one line>`, then frontmatter (`id`, `date`, `trigger` — a *condition*, not a vibe, `weight`, `occurrences`, `status`), then `## Failure pattern`, `## Correction`, `## Rule`, `## Why it mattered` with the verbatim evidence quoted.
5. Update `INDEX.md` with a delta: add/edit only the affected lines (`NNNN [weight] — summary`).
6. Check promotions: any lesson now at weight ≥ 3.0 → execute the promotion rule above.
7. If ledger entries were processed into lessons, note it in `.claude/memory/activity-log.md` and clear the processed entries from the ledger (they've been converted; keeping them would re-surface handled failures at session start).
