---
updated: {{DATE}}
---

# {{PROJECT_NAME}} task list

Canonical, human-authored task breakdown. Machine-readable mirror + live health: `.claude/state/status.json` (its `health` block is hook-maintained — do not hand-edit).

**Status legend** (exactly six values, used consistently here and in `status.json`):

| Status | Meaning |
|---|---|
| `pending` | Not started. |
| `running` | Actively being worked on this session. |
| `needs-fix` | Exists and builds, but a check/review flagged an issue. |
| `broken` | Build or tests currently failing for this task's code. |
| `upgrading` | In-progress dependency/version/schema-migration work. |
| `completed` | Done **and** verified end-to-end per `.claude/rules/ship-verification.md`. |

Each task: `### #NNN <title>`, then `Status:`, `Files:`, `Notes:` (one line each, grep-friendly).

---

### #001 (replace with your first task)
Status: pending
Files: (expected files)
Notes: (context, done-condition)
