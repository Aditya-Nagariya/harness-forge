---
name: declutter
description: "Remove dead code, unused dependencies, commented-out blocks, and orphaned files once a checkpoint is reached — for long-term maintainability. Evidence-gated and reversible: nothing is removed without proof it is unreferenced, and build+tests must stay green after every batch. Run after a milestone/feature completes, not mid-implementation."
disable-model-invocation: true
argument-hint: "[path-or-scope]"
---

Codebases rot: dead code, unused deps, and commented-out blocks accumulate and make every future change harder and every context read more expensive. This skill prunes them at a **checkpoint** (a completed milestone/feature — not mid-work, where "unused" often means "not wired up *yet*"). It is deliberately conservative: **removal requires evidence, and every batch is verified and revertible.**

## Preconditions (stop if any fails)

1. Working tree is clean or the current work is committed — declutter starts from a known-good commit so any step is revertible with `git restore`/`git reset`.
2. Build and tests are green *before* starting (source `.claude/harness.env`; run `$BUILD_CMD` and `$TEST_CMD`). Never declutter on a red baseline — you can't tell your removal from a pre-existing failure.
3. This is a checkpoint, not mid-feature. If a `TASKS.md` item is `running`/`broken`, finish it first.

## What to look for (evidence source in parentheses)

- **Dead code** — unused functions, types, variables, imports, private items with zero references. Evidence: the language's own tooling first (compiler dead-code warnings; `cargo build`/clippy `dead_code`; TS `knip`/`ts-prune`; Python `ruff --select F401,F811`/`vulture`; Go `deadcode`/`staticcheck`), then a repo-wide `grep`/`rg` for the symbol confirming zero call sites.
- **Unused dependencies** — declared but never imported (`cargo-machete`/`cargo +nightly udeps`; `depcheck`/`knip`; `pip-autoremove`/`deptry`).
- **Commented-out code blocks** — not doc comments; blocks of disabled code. Git history is the archive; delete them.
- **Orphaned files** — modules/assets nothing imports or references; leftover `*.forge-new` merge artifacts; empty directories; stale generated files that should be regenerated not committed.
- **Redundant abstractions** — one-caller indirection introduced "for future flexibility" that never arrived; duplicate helpers (grep for near-identical bodies).

## Protocol — small, verified, reversible batches

1. **Discover + verify in one pass.** Run the `declutter` workflow (`.claude/workflows/declutter.js`) — it discovers candidates (dead-code/dep tooling + a naming/duplicate-pattern sweep), then verifies each one empirically in a single parallel Explore fan-out, one agent per candidate (no separate verify phase; each investigation prompt itself carries "don't trust the name/comment, verify the real wiring"). Report the four buckets it returns, **lede first** (confirmed-dead count and the highest-impact promote-candidate before any per-item detail):
   - **Confirmed dead** — zero references anywhere, evidence-backed (the grep/tool output is in `evidence`). These are the only items that proceed to step 3.
   - **Trap** — looked dead but a guard-zone exception or a hidden reference makes it still needed (e.g. a file labeled "ARCHIVED" that's still wired in). Do not touch; the `evidence` field is why.
   - **Promote candidate** — not dead, but a duplicate/consolidation opportunity (one copy should absorb the other). Flag as a follow-up `TASKS.md` item; never resolve by blindly deleting either copy.
   - **Needs your call** — evidence is genuinely ambiguous or conflicting. Present it verbatim and wait for the user's decision before doing anything with it.
2. **Guard the danger zone.** Do NOT remove, without explicit confirmation: exported/public API surface (may be used by external callers the repo can't see), anything behind a feature flag / `#[cfg(...)]` / conditional build (check *all* configs, not just the default), test fixtures, or anything referenced only in docs/config/CI. "No caller in this repo" ≠ "unused" for a public symbol — the workflow's `trap` bucket exists precisely to catch this.
3. **Remove in small batches** grouped by area, committing after each: e.g. "remove unused imports", then "drop 3 dead helpers", then "remove 2 unused deps". One concern per commit so any regression bisects cleanly.
4. **Verify after every batch** (`.claude/rules/ship-verification.md` applies): `$BUILD_CMD` + `$TEST_CMD` must stay green, and if the removal touched runtime behavior, actually run the affected path. If anything goes red, `git restore` that batch and record why it wasn't actually dead (that's a lesson for `/learn` — the reference the tool missed).
5. **Update the map.** If you removed something CLAUDE.md/HARNESS.md/GUIDE.md named, update those pointers. Remove resolved `*.forge-new` files.
6. **Report** what was removed, the evidence per item, the batches/commits, and the before→after (files, lines, dependency count). Note anything you deliberately *kept* and why (trap/needs-your-call items).

## Hard rules

- Never delete on a red baseline; never delete without either tool-proof or grep-proof of zero references; never mix decluttering with feature work in the same commit; never remove public API or cfg-gated code without explicit user confirmation. When unsure whether something is dead, it stays — a false "unused" removal that ships is worse than a little lingering cruft.
