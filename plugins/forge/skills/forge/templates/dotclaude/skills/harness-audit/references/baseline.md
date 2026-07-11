# Harness baseline

The agreed, decided state of this project's harness — what it should look like. `/harness-audit` reads this first every run so it doesn't re-derive facts already settled; when this file and the audit's general method disagree, **this file wins** — it's the project's decided design. Phase 4 of every audit appends to §6 (change log) below.

## 1. Source-of-truth table

| Knowledge kind | Canonical home | Rule |
|---|---|---|
| Corrections/learnings | `.claude/memory/lessons/*.md` | One entry per external-evidence correction; weight ≥3.0 → promote (see `GUIDE.md` §4.2) |
| Why a decision was made | `.claude/memory/decisions.md` | Append-only, one line per decision |
| What happened | `.claude/memory/activity-log.md` | Append-only, one line per completed unit of work |
| Technical bug recipes | `.claude/issues-solved/*.md` | Grep `INDEX.md` before debugging; see `GUIDE.md` §4.3 |
| Open work | `.claude/tasks/TASKS.md` | Six-status vocabulary; see `GUIDE.md` §4.1 |
| In-progress design bigger than a task line | `.claude/plans/<slug>` | See `plans/README.md` and `GUIDE.md` §4.7 |
| This harness's own agreed design | `.claude/skills/harness-audit/references/baseline.md` (this file) | Updated by `/harness-audit` Phase 4 only |

## 2. Canonical load order

1. `.claude/CLAUDE.md` (always-loaded index)
2. `.claude/GUIDE.md` (on-demand, read before touching harness structure)
3. `.claude/tasks/TASKS.md` (current open work)
4. This file, when running `/harness-audit`

Every path named above MUST resolve — a dead pointer here is itself a Phase 2 finding.

## 3. Naming/trigger conventions

- Agent/skill `description:` frontmatter must be a double-quoted YAML scalar if it contains a colon or `#` — an unquoted one containing `: ` parses as a nested mapping and **silently de-registers the file** (lesson 0002).
- Lesson files: `NNNN-slug.md`, zero-padded 4 digits, one-line `Summary:` first.
- Issues-solved files: same numbering discipline — see Phase 2 item 13's numbering-integrity check.

## 4. Wiring table (seams that must stay connected)

| Seam | Written by | Read by | Cleared/reset by |
|---|---|---|---|
| Failure signal | `hooks/capture-failure.sh` | `hooks/session-start.sh` (hotspots), `/learn` | `/learn` clears handled entries |
| Lesson promotion | `/learn` (weight ≥3.0) | `/harness-audit` Phase 2 item 9 | — |
| Routing outcomes | caller of `workflows/elevate.js` (the workflow itself cannot write files) | `/harness-audit` Phase 2 item 14 | — |
| Agent memory | agents with `memory: project` | same agent, next invocation | never auto-cleared |
| Config drift fingerprint | `hooks/session-start.sh` | same hook, next session | overwritten each session |

## 5. Known gotchas

- (seed this section as you discover project-specific gotchas — dated, one paragraph each, causally explained: what broke, why, what the fix was)

## 6. Change log

- (Phase 4 of every `/harness-audit` run appends one dated line here: what changed, why)
