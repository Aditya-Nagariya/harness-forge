# The Management System

How every file, folder, and piece of data in this project is organized, who may write it, and how it evolves. This guide is written so that **any model, of any size, can operate here correctly by following rules instead of exercising judgment.** When in doubt, this document wins.

---

## 1. The four zones

Every file in this repository belongs to exactly one zone. The zone determines who writes it, whether it's committed, and how it's updated.

| Zone | What | Examples | Committed? | Updated by |
|---|---|---|---|---|
| **A — Source** | The product itself | `src/`, tests, build manifests | yes | humans + agents doing tasks |
| **B — Harness code** | The machinery that makes agents effective | `.claude/hooks/`, `skills/`, `agents/`, `workflows/`, `rules/`, `evals/`, `settings.json`, `statusline.sh`, `loop.md`, `GUIDE.md` | yes | `/forge` upgrades + deliberate harness work only |
| **C — Durable knowledge** | What the project has learned | `.claude/memory/` (lessons, decisions, activity-log, research), `issues-solved/`, `tasks/`, `agent-memory/`, `harness.env`, `CLAUDE.md`, `state/status.json` | yes | agents + humans, via the lifecycle rules in §4 |
| **D — Machine-local state** | Signals and scratch, valid on this machine only | `state/failure-ledger.jsonl`, `state/routing-stats.json`, `state/.HANDOFF.md`, `hooks-state/`, `worktrees/`, build output | **never** (gitignored) | hooks automatically |

Three invariants that follow from the zones:

1. **Zone B is edit-protected.** A hook blocks Write/Edit on `.claude/hooks/*` (the machinery can't be edited away by the machinery it constrains). Harness changes are deliberate acts: made by `/forge` upgrades, or by a human-reviewed edit outside the agentic loop.
2. **Zone C is delta-only.** Knowledge files are appended to or edited line-by-line — never regenerated wholesale by a model. (Evidence: full LLM rewrites of evolving stores cause documented "context collapse" — see `.claude/memory/research/`.)
3. **Zone D is disposable.** Anything in zone D can be deleted with zero data loss beyond convenience. If deleting a file would lose knowledge, it's in the wrong zone — move it to C.

## 2. Placement decision tree — "where does this new file go?"

```
Is it product code, product tests, or product config?      → Zone A (src tree). Done.
Is it a script/prompt/config that changes agent behavior?  → Zone B. Are you sure it
   shouldn't be a lesson first? New harness machinery needs demonstrated evidence
   (a failure it would have prevented) — see §5.
Is it something learned, decided, done, or planned?
   A mistake + its correction                               → memory/lessons/NNNN-slug.md  (§4.2)
   A technical bug recipe (>2 iterations or >5 min)         → issues-solved/NNNN-slug.md   (§4.3)
   Why a non-obvious choice was made                        → memory/decisions.md (append one entry)
   What happened (log line)                                 → memory/activity-log.md (append one line)
   Work to do / in progress                                 → tasks/TASKS.md (§4.1)
   Agent-specific operational knowledge                     → agent-memory/<agent>/MEMORY.md
Is it a transient signal, cache, or scratch?                → Zone D. Confirm it's gitignored.
None of the above?                                          → It probably shouldn't exist. Ask.
```

**Hard rule for all models:** do not create new top-level directories, new "notes.md"/"summary.md"/"output.txt"-style files, or parallel copies of existing files (`file_v2.md`, `file_final.md`). If content has no home in the tree above, it goes in the conversation, not the filesystem.

## 3. Who writes what — the permission matrix

| Writer | May write | Must never write |
|---|---|---|
| **Hooks** (deterministic) | `state/status.json` health block, `failure-ledger.jsonl`, `hooks-state/`, activity-log health-flip lines, fingerprint | anything in Zone A or B |
| **Orchestrator** (main session) | Zone A (tasks), Zone C per lifecycle rules | Zone B (hook-blocked), Zone D directly (hooks own it) |
| **Worker agents** (small-executor etc.) | Zone A within their one step; their own `agent-memory/<name>/MEMORY.md` | anything in `.claude/` outside their memory dir |
| **Verifier/reviewer agents** | nothing (read-only by tool allowlist) | everything |
| **`/forge`** | Zone B (hash-guarded), Zone C seeds only-if-absent | existing Zone C content, `harness.env` after install |
| **Human** | everything | — |

## 4. Lifecycle rules (the part that makes the system self-improving)

### 4.1 Tasks — `tasks/TASKS.md`

Six statuses, exactly: `pending → running → completed`, with `needs-fix` (built but flagged), `broken` (build/tests failing), `upgrading` (dependency/migration work) as side states. Entry format: `### #NNN title` + `Status:`/`Files:`/`Notes:` lines (grep-friendly). Rules:
- One task `running` per working session at a time; flip status *before* starting work, not after.
- `completed` requires a verification statement per `rules/ship-verification.md` — an exact command and its observed result. No statement, no completion.
- Completed entries move to `ARCHIVE.md` (full entry + `Completed:` date + verification line). TASKS.md holds only open work.
- `status.json`'s `tasks` array mirrors TASKS.md; its `health` block belongs to the hooks — never hand-edit it.

### 4.2 Lessons — `memory/lessons/` (the learning loop)

- **One lesson per file**: `NNNN-short-slug.md`, first line `Summary: <one line>`, then frontmatter (`id`, `date`, `trigger` — a condition, not a vibe — `weight`, `occurrences`, `status`), then Failure pattern / Correction / Rule / Why it mattered, quoting verbatim evidence.
- **Admission**: only from external evidence — an error message, a failing command, a user correction. No evidence, no lesson.
- **Write policy** (enforced by `/learn`): retrieve similar lessons first, then ADD / UPDATE / UPVOTE (+1.0) / DOWNVOTE (−1.0, when the failure recurred despite the lesson). Never blind-append near-duplicates. All edits are deltas.
- **INDEX.md**: one line per lesson (`NNNN [weight] — summary`); top 3 by weight are auto-injected each session start; the rest load only when a trigger matches.
- **Promotion at weight ≥ 3.0**: mechanically checkable → becomes a hook (with a block-path test fixture) or a regression check in `evals/regressions/`; judgment-based → one line in CLAUDE.md. Then mark `status: promoted`.
- **Retirement at weight ≤ 0**: mark `status: retired` (keep the file; set `superseded_by:` if replaced). Invalidate, don't delete.

### 4.3 Issues solved — `issues-solved/`

Technical bug recipes (vs. lessons, which are behavior corrections). Add when a bug took >2 iterations, >5 minutes, or external research. Grep `INDEX.md` **before** debugging anything — a match means apply the known fix, don't re-derive. Include "Failed attempts (do NOT retry)" — negative knowledge is as valuable as the fix.

### 4.4 Failure ledger → lessons (the self-healing loop)

`capture-failure.sh` records every tool failure with a normalized signature (paths/numbers stripped, so the same failure class groups). Signatures repeating ≥2× surface at session start with a prompt to run `/learn`. After `/learn` converts a signature into a lesson, clear those entries from the ledger — handled signal shouldn't re-surface.

### 4.5 Regression evals — `evals/regressions/`

Every *confirmed* past failure that can be mechanically detected becomes a permanent `NNNN-*.sh` check (exit 0 = safe, nonzero = the old failure is back). Run by `/harness-audit`, `/ship` (when the harness changed), and CI. Rules prevent; regression checks detect recurrence.

### 4.6 Agent memory — `agent-memory/<name>/MEMORY.md`

Each agent with `memory: project` accumulates institutional knowledge here (auto-injected into that agent, first 200 lines / 25KB). Keep entries to 1–2 lines; curate past ~150 lines by consolidating, not deleting evidence-bearing entries. Read `MEMORY.md` the file — never the directory path itself.

## 5. Evolving the harness itself (Zone B changes)

The harness is versioned, tested software. A Zone B change requires all three:
1. **Evidence** — a ledger signature, a promoted lesson, or a failed audit check that the change addresses. No demonstrated failure mode → no new machinery (scaffold churn is a cost, not an improvement).
2. **A test** — new/changed hooks need fixtures (including the block path — a gate whose block path is untested has "silently allow" as its failure mode); new checks go in `evals/regressions/`.
3. **A record** — one line in `memory/decisions.md` saying why.

`/harness-audit` is the maintenance pass (mechanical invariants, drift, dead weight). `/forge` (the installer plugin) delivers upstream harness upgrades: pristine files update automatically; files you've modified are never clobbered — the new version arrives as `<file>.forge-new` for explicit merge.

## 6. Context economy (why the structure looks like this)

- **Always-loaded** (costs every turn): CLAUDE.md + unscoped rules. Budget: keep the total under ~1,200 tokens. Every line must earn its place; procedures belong in skills (zero cost until invoked), enforcement belongs in hooks (zero context cost, 100% compliance).
- **Injected at session start** (bounded): health summary, open-task count, top-3 lessons, failure hotspots — a fixed-size digest, never a growing file.
- **Just-in-time** (on demand): full lessons, issues-solved entries, research digests, this guide — loaded when a trigger matches, not by default.
- Instruction-following degrades as rule count grows, and small models degrade fastest — which is why mature rules migrate out of prose into hooks, and why this guide is a reference document rather than an always-loaded rulebook.
- **Regulator:** `/context-budget` (script: `.claude/scripts/context-budget.sh`, gated in CI) measures the always-loaded total and fails over the cap. A self-improving harness accretes rules and lessons; without this it silently bloats. Run it whenever CLAUDE.md or the rules grow.

## 6a. Checkpoint hygiene (keeping the codebase maintainable)

When a milestone/feature completes and the tree is green — a **checkpoint** — prune before moving on, so cruft never compounds:

- `/declutter` removes dead code, unused dependencies, commented-out blocks, and orphaned files. It is evidence-gated (nothing goes without tool-proof or grep-proof of zero references) and reversible (build+tests must stay green after every small batch; a red result reverts that batch). It runs at checkpoints only — mid-feature, "unused" often means "not wired up yet."
- Guard zone (never removed without explicit confirmation): public/exported API, `cfg`/feature-flag-gated code (check *all* configs), test fixtures, doc/CI-referenced items.
- This is the maintainability counterpart to the lesson store's grow-and-refine: the harness accumulates knowledge *and* sheds dead weight, so both the context and the codebase stay lean over time.

## 7. Operating protocol for small models

If you are a small/fast model working in this repository, follow these and you will perform at the level of a much larger one:

1. **One narrow step at a time.** If your assignment contains "and," it may be two steps — say so and let the orchestrator split it.
2. **Check memory first**: your `MEMORY.md`, the lessons INDEX, `issues-solved/INDEX.md` — in that order — before reading code.
3. **Reason in prose, then act, then format.** Don't emit structured output while still deciding.
4. **Every claim needs a command.** "Done" means: here is the command I ran and its output tail. No output, no claim.
5. **Two failures = stop and report.** Escalation is cheaper than your third attempt. Report the exact error, not a summary of it.
6. **Never free-form self-critique.** Verification happens against checklists (`small-verifier` aspects) or real command output — not your opinion of your own work.
7. **Write down what you learned** — one line in your `MEMORY.md` — before you finish. Knowledge that stays in a transcript is knowledge lost.

## 8. Git policy summary

Committed: zones A, B, C — including `agent-memory/` and `state/status.json` (shared team knowledge) and `state/.fingerprint.json` (shared drift baseline). Gitignored: all of zone D, plus `CLAUDE.local.md` (personal) — the forge-appended block in `.gitignore` is the canonical list. Never commit: secrets (hook-scanned), lockfile hand-edits (hook-blocked), `*.forge-new` merge artifacts (resolve them, then delete).
