---
name: ship
description: "Confirmed commit/push/PR pipeline — stage, commit, push, open a PR. Never runs unattended; every destructive or outward-facing step is confirmed first."
disable-model-invocation: true
---

## Steps (confirm before each state-changing one)

1. **Scan.** `git status`, `git diff`, `git diff --cached`, `git log -5 --oneline`. Summarize what's about to be shipped.
2. **Gate.** Source `.claude/harness.env`; run `$BUILD_CMD`, `$TEST_CMD`, `$LINT_CMD` (each that is set), plus `bash .claude/hooks/tests/run-all.sh` and `bash .claude/evals/regressions/run-all.sh` if the diff touches the harness itself. Do not proceed to stage/commit if any fail — report and stop.
3. **Stage & commit.** Never stage: `.env*`, secret-shaped files, lockfile hand-edits, build output, OS junk. Draft a commit message matching this repo's existing style (Conventional Commits per `.claude/rules/git-workflow.md` if present). **Ask for confirmation before running `git commit`.**
4. **Update TASKS.md.** If this commit completes a `TASKS.md` item, move it to `ARCHIVE.md` with a verification line per `.claude/rules/ship-verification.md` — verified end-to-end, not just compiled.
5. **Push.** Only if a remote is configured and the branch isn't protected. **Ask for confirmation before pushing.**
6. **PR.** Only if `gh` is available and a remote exists. Check for an existing PR via `gh pr view` first. Draft title (<72 chars) and body (Summary + Test plan) from the full commit range. **Ask for confirmation before creating.**

Hard rules: never skip a confirmation step, never `--force` push, never commit content the secret scanner flagged without explicit user override, never push directly to a protected branch.
