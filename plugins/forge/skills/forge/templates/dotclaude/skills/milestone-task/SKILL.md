---
name: milestone-task
description: "Test-driven implementation flow for one TASKS.md item — load, red, green, refactor, verify, archive — driving the six-status vocabulary. Use when picking up any pending task."
argument-hint: "[task id, e.g. #001]"
---

Work exactly one `TASKS.md` item ($ARGUMENTS) through `pending → running → completed` (or `→ needs-fix`/`→ broken` if something goes wrong).

## Steps

1. **Load the task.** Read its `TASKS.md` entry (Status/Files/Notes) and any spec it references.
2. **Flip status to `running`** in `TASKS.md` before starting.
3. **Red.** Write one failing test capturing the smallest slice of the behavior; confirm it fails for the expected reason.
4. **Green.** Minimum code to pass that one test (hardcoding is fine if only one test forces it).
5. **Refactor** only with tests green — one transformation at a time, re-run after each.
6. **Repeat** red→green→refactor per slice until the requirement is covered. If the task turns out bigger than one step, split it and note that in `TASKS.md` — don't silently scope-creep.
7. **Gate.** Run build + test + lint + format from `.claude/harness.env`; all must pass.
8. **Verify** per `.claude/rules/ship-verification.md` — actually run the behavior end-to-end, not just unit tests, if it touches a runtime path.
9. **Archive.** Move the entry to `ARCHIVE.md` with a `Completed:` date and how it was verified; set its `status.json` entry to `completed`.

If you hit a wall (spec unclear, design needs revisiting), stop and flag it — flip status to `needs-fix` with a note, never leave it silently `running`.
