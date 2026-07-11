# plans/

For design work bigger than a `TASKS.md` line, smaller than shipped code. Empty by design between features — a non-empty `plans/` (other than `archive/`) means work is genuinely in flight.

## When to add a plan here

- A new feature touching 3+ files.
- A cross-service/cross-module refactor.
- Any work where the executor (`/milestone-task`, `small-executor`, `bug-fixer`) needs a DAG or a multi-step design to follow, not just a one-line task.

## When NOT to

- Single-line bug fixes, typo/formatting, status updates/triage — those stay in `tasks/TASKS.md`.

## Single file vs. folder (the decision that matters)

- **Default: a single file**, `plans/<slug>.md`, covering the design in one document (problem, approach, acceptance criteria, rollback). Most plans fit here.
- **Folder, `plans/<slug>/`, only when the work needs genuinely separable documents** — e.g. investigation must be readable independently of the decided design (`DISCOVERY.md` + `PLAN.md`), or a regression-gate baseline must be captured once and referenced by multiple later phases (`BASELINE.md`), or a low-reasoning executor needs a distinct literal-instructions document separate from the rationale-carrying plan (`EXECUTION_GUIDE.md`).
- **Every folder MUST contain `PLAN.md` as the entry point**, even if thin — never let the actual plan live only inline in a giant `TASKS.md` entry with no canonical doc elsewhere.

## Status

The first line of `PLAN.md` (or the folder's `PLAN.md`) states its status as plain text, not frontmatter — keep it grep-able like everything else in this harness:

```
Status: draft | active | archived
```

`draft` = written, awaiting sign-off. `active` = approved, in progress. `archived` = shipped or abandoned (see below).

## A `BASELINE.md` is mandatory for any plan involving a refactor with a no-regressions requirement

Record an exact, falsifiable snapshot before risky work starts — e.g. `342 passed / 8 failed`, plus the explicit gate for every later phase: `exactly these 8 failures, zero new`. "No regressions" needs a number to be checked against, not a vibe.

## On ship or on abandon — archive it, don't leave it

Move the whole file or whole folder to `plans/archive/<slug>.md` / `plans/archive/<slug>/`, and add a one-line pointer in the closed `tasks/ARCHIVE.md` entry. This is a single, explicit, atomic step — `/harness-audit` checks for it (a `TASKS.md`/`ARCHIVE.md` entry marked done whose matching `plans/<slug>` hasn't been archived is flagged, not silently left). Do this consistently for both single-file and folder plans — a plan that's easy to forget to archive because it's "just a folder" is exactly the failure mode this rule exists to prevent.

## Context economy

A `plans/` document is **not** part of the always-loaded budget (`.claude/GUIDE.md` §6 / `/context-budget`) — it's opt-in reading for whoever picks up that specific feature, never autoloaded, and should never be wired into `CLAUDE.md`'s index.
