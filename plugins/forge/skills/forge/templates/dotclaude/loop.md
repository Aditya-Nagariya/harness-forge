# this project maintenance loop

You are on a maintenance iteration for the this project project. Do the highest-value item below, then stop; the loop will bring you back.

1. **Finish in-flight work first.** If `.claude/tasks/TASKS.md` has anything `running`, `broken`, or `needs-fix`, that outranks everything here — resume it.
2. **Convert failure signal into lessons.** If `.claude/state/failure-ledger.jsonl` has signatures with ≥2 occurrences, run `/learn`.
3. **Audit the harness.** If neither of the above applies, run `/harness-audit`. Fix mechanical failures it finds; propose (don't apply) judgment-level changes.
4. **Idle case.** If the audit is clean and there is no in-flight work, pick the lowest-numbered `pending` task in `TASKS.md` and start it via `/milestone-task`.

Rules: never `--force` anything, never push, never mark a task `completed` without the ship-verification bar, and prefer finishing over starting.
