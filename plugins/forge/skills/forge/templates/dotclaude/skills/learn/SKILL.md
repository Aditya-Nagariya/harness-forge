---
name: learn
description: "Convert this session's failures and user corrections into durable per-file lessons in .claude/memory/lessons/, following the evidence-backed write policy (retrieve-similar-first, delta updates, weighted vote lifecycle, hook promotion). Run at the end of any session that contained a correction or a repeated failure."
---

The continuous-learning half of the self-healing loop. The raw signal comes from `.claude/state/failure-ledger.jsonl` (written automatically by `capture-failure.sh`) and from user corrections in this session's conversation. This skill's design follows specific published findings — keep these properties intact when executing it:

- **External evidence only.** A lesson must quote a concrete artifact: a verbatim error message, a failing command's output, or the user's actual correction. If there is no external evidence, do not write a lesson — model self-judgment is not a valid trigger (intrinsic self-correction demonstrably degrades performance; Reflexion-class gains come from evaluator-grounded reflections).
- **Retrieve before writing.** Before adding anything, grep `.claude/memory/lessons/INDEX.md` and the lesson files for similar content, then choose one of: **ADD** (genuinely new), **UPDATE** (same lesson, better wording/trigger), **UPVOTE** (the lesson exists and was confirmed again), **DOWNVOTE** (the failure recurred *despite* the lesson existing, meaning the lesson isn't working as written — rewrite its trigger or rule). Never blind-append a near-duplicate.
- **Delta updates only.** Edit individual lesson files and individual INDEX lines. Never rewrite INDEX.md or a lesson file wholesale from memory — full LLM rewrites are the documented cause of "context collapse" in evolving-context systems.
- **Lifecycle:** at weight ≥ 3.0, **promote**: if the rule is mechanically checkable, its terminal form is a *hook* (with test fixtures) or a *regression check* in `.claude/evals/regressions/` — not more prose (hooks get ~100% compliance; advisory rules get 70–90% and dilute each other). If judgment-based, add one line to CLAUDE.md and mark the lesson `status: promoted`. At weight ≤ 0, mark `status: retired` (keep the file; set `superseded_by:` if replaced — invalidate, don't delete).

## Signal classification (do this before deciding ADD/UPDATE/UPVOTE/DOWNVOTE)

Not every correction carries the same weight. Classify the signal, then apply its initial weight (new lesson) or its delta (existing lesson):

| Signal type | Example | Weight (new) / delta (existing) |
|---|---|---|
| Explicit correction | User says "no," "wrong," "stop doing that" | 1.0 |
| Implicit reframe | User rephrases/re-asks without an explicit "no" | 0.5 |
| Single mood/preference, no recurrence | A one-off style preference stated once, not repeated | 0.2 |
| Self-induced | A hook blocked something, or you caught your own factual error | 0.8 |
| Positive confirmation | User explicitly confirms an approach worked well ("yes exactly," "perfect, keep doing that") | 0.5 UPVOTE on an existing lesson — do not create a brand-new lesson from a single positive confirmation alone (risk of self-serving noise); only log it as a NEW lesson if it's a genuinely non-obvious approach validated after real ambiguity |

**Anti-signal — do NOT log a lesson for:** a user simply answering a clarifying question (not a correction), a one-off typo fix with no behavioral pattern, praise with no specific approach being confirmed ("great job" alone), or anything you can't quote verbatim evidence for.

Promote at cumulative **weighted_sum ≥ 3.0** (not raw occurrence count) — this prevents one emphatic explicit correction plus two shallow implicit nudges from over-promoting a lesson that isn't actually load-bearing, and prevents a single mood-driven preference from ever reaching promotion on its own.

## Trust gate when *consuming* a lesson (distinct from the write policy above)

The write policy governs how lessons get created. Separately, when a lesson influences what you do *right now* while acting (not just when you're writing a new one), apply an asymmetric check:

- **A lesson telling you to ADD/use something** → needs a citation you can actually point to (the lesson's file:line, or the rule it's based on). No citation = don't let it override your own read of the current situation.
- **A lesson telling you NOT to do something the user just asked for** → needs an anchor: an explicit rule conflict, a lesson at weight ≥ 3.0 (i.e., already promoted/repeatedly confirmed), or a deterministic check (a hook block, a failing test) — not just "a lesson file mentioned something vaguely similar once." A soft pattern-match alone should be *surfaced to the user* ("a past lesson suggests X — want me to follow it here?"), not silently auto-applied to block their request.

This prevents a single noisy, stale, or over-generalized lesson from silently overriding legitimate new work.

## Steps

1. Read `.claude/state/failure-ledger.jsonl` (if present). Group by `signature`; any signature with ≥2 occurrences is a lesson candidate.
2. Scan this session's conversation for corrections and confirmations, classifying each per the table above, and for failure→success contrast pairs (the strongest lessons state what *changed* between the failed and successful attempt).
3. For each candidate, apply the retrieve-before-writing policy (ADD/UPDATE/UPVOTE/DOWNVOTE), using the classified weight/delta.
4. For ADDs: create `.claude/memory/lessons/NNNN-short-slug.md` (next free number — verify against **both** `INDEX.md`'s claimed next-free number **and** an actual `ls .claude/memory/lessons/`, since the note alone can drift behind concurrent writes) in the exact format of the existing files — first line `Summary: <one line>`, then frontmatter (`id`, `date`, `trigger` — a *condition*, not a vibe, `weight`, `occurrences`, `status`), then `## Failure pattern`, `## Correction`, `## Rule`, `## Why it mattered` with the verbatim evidence quoted.
5. Update `INDEX.md` with a delta: add/edit only the affected lines (`NNNN [weight] — summary`).
6. Check promotions: any lesson now at weighted_sum ≥ 3.0 → execute the promotion rule above.
7. If ledger entries were processed into lessons, note it in `.claude/memory/activity-log.md` and clear the processed entries from the ledger (they've been converted; keeping them would re-surface handled failures at session start).
