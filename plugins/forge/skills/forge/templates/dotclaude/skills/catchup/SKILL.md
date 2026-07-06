---
name: catchup
description: "Session-resumption summary — reads git state, TASKS.md, and status.json to produce a terse Goal/Done/In-flight/Next/Watch-out summary. Use at the start of a session after time away, or pass 'handoff' to write one before ending a session."
argument-hint: "[handoff]"
---

Layered on top of what `session-start.sh` already injects automatically (health + open-task count + lessons) rather than duplicating it.

## Default mode (no arguments)

1. Read `.claude/state/.HANDOFF.md` if it exists (written by a prior `handoff` run).
2. `git log --oneline -10` and `git diff --stat` since the merge-base with the tracked upstream (or `HEAD~5` if no upstream).
3. Read `.claude/tasks/TASKS.md` for anything `running`/`needs-fix`/`broken` right now.
4. Produce a terse summary in this exact template (skip sections with nothing to say):
   ```
   Goal: <what this work session/milestone is aiming at>
   Done: <what's landed since the last handoff>
   In flight: <tasks currently running/needs-fix/broken, with TASKS.md IDs>
   Next: <the next concrete step>
   Watch out: <any known gotcha>
   ```

## `handoff` mode ($ARGUMENTS contains "handoff")

Write `.claude/state/.HANDOFF.md` (gitignored), under 30 lines, sections Goal/State/Gotchas/Next step, overwriting any previous handoff. This is disposable scratch — the permanent record is `.claude/memory/activity-log.md`.
