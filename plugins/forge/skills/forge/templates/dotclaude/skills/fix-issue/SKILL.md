---
name: fix-issue
description: "Structured debugging flow — check issues-solved/ first, reproduce, fix the root cause, verify end-to-end, and capture a new issues-solved entry if it was non-trivial. Use when a bug is reported or a test fails unexpectedly."
argument-hint: "[symptom or error message]"
disable-model-invocation: true
---

The "issue" is whatever symptom/error the user describes: $ARGUMENTS.

## Steps

1. **Check the bug database first.** Grep `.claude/issues-solved/INDEX.md` for keywords from the symptom. On a match, read the linked entry and apply the known fix instead of re-deriving it.
2. **Reproduce.** Get the failure happening reliably before touching code — run the failing command/test and confirm the exact symptom. If you can't reproduce it, say so rather than guessing.
3. **Investigate root cause**, not the symptom. Check adjacent/mirrored code paths (e.g. both sides of a platform or config split), where regressions often hide.
4. **Fix** — smallest change that addresses the root cause. Follow `.claude/rules/`.
5. **Verify** per `.claude/rules/ship-verification.md`: re-run the reproduction (now passing), then the full test command from `.claude/harness.env`, then — if the bug was in a runtime path — actually run the affected behavior and inspect real output.
6. **Capture** if it took >2 iterations, >5 minutes, or external research: copy `.claude/issues-solved/TEMPLATE.md` to `NNNN-slug.md` (include "Failed attempts"), prepend a row to `INDEX.md`. If it's a behavior/process mistake rather than a code recipe, run `/learn` instead.
7. **Update `TASKS.md`/`status.json`** if this bug blocked a tracked task.

Hand off to `/ship` when done; don't self-commit as part of this skill.
