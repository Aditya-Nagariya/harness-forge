# {{PROJECT_NAME}} maintenance loop

You are on a maintenance iteration. Do the highest-value item below, then stop; the loop will bring you back.

**Step 0 (always, first action, before anything else).** Run `bash .claude/scripts/record-loop-run.sh`. This stamps `.claude/state/last-loop-run.json` immediately so `capability-gate.sh` sees `/loop` as current — otherwise steps 1 and 5 below (which can involve editing real source files) would be blocked by the very gate this run is meant to satisfy, since the gate's "loop ran recently" check wouldn't be true yet. Running it again as the final step (below) is harmless and keeps the timestamp reflecting actual completion time too.

1. **Finish in-flight work first.** If `.claude/tasks/TASKS.md` has anything `running`, `broken`, or `needs-fix`, that outranks everything here — resume it.
2. **Convert failure signal into lessons.** If `.claude/state/failure-ledger.jsonl` has signatures with ≥2 occurrences, run `/learn`.
3. **Checkpoint hygiene (only when a milestone/feature just completed and the tree is green).** Run `/context-budget`; if it's NEAR LIMIT or OVER, trim per that skill. Then run `/declutter` to prune dead code / unused deps / orphaned files accumulated during the feature. Skip both mid-feature.
4. **Audit the harness.** If none of the above applies, run `/harness-audit`. Fix mechanical failures it finds; propose (don't apply) judgment-level changes.
5. **Idle case.** If everything is clean and there is no in-flight work, pick the lowest-numbered `pending` task in `TASKS.md` and start it via `/milestone-task`.

Rules: never `--force` anything, never push, never mark a task `completed` without the ship-verification bar, and prefer finishing over starting.

## Unattended mode

If the `$FORGE_UNATTENDED` environment variable is set, nobody is watching this run in real time:

- Skip `/ship`'s commit/push steps entirely, regardless of how confident the change looks. A task reaching `/milestone-task`'s or `/ship`'s commit point stops at "implemented and verified, NOT committed" — an `ask`-style confirmation would hang forever with nobody to answer it.
- As your final action, write `.claude/state/unattended-runs/<UTC timestamp, format YYYY-MM-DDTHH-MM-SSZ>-summary.md` (use `-` not `:` in the time portion — colons are invalid in filenames on some filesystems) containing: what step of the loop ran, what was done, the exact verification commands run and their output, and the working tree's current `git status --short` so the next interactive session can review and decide whether to commit.

## Final step (always, both modes)

Run `bash .claude/scripts/record-loop-run.sh` as your last action, whether or not `$FORGE_UNATTENDED` is set — this is what tells `capability-gate.sh` the loop ran.
