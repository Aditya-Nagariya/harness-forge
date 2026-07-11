# harness-forge

One slash command that installs — and later upgrades — a **self-improving Claude Code harness** in any project. The harness it forges makes agents (including small/fast models like Haiku) safer, cheaper, and measurably more reliable, and it gets better over time by converting its own failures into durable, promoted rules.

Want to contribute? See [ROADMAP.md](ROADMAP.md) for independent, self-contained feature write-ups — pick one and you'll know exactly what's being asked and why.

## What the forged harness contains

| Layer | Mechanism |
|---|---|
| **Self-healing** | Every tool failure is auto-recorded with a normalized signature (`capture-failure.sh` → machine-local ledger); repeats surface at session start with a prompt to convert them into lessons. |
| **Continuous learning** | Per-file lesson store with trigger conditions, verbatim evidence, and a vote lifecycle. `/learn` classifies each signal (explicit correction / implicit reframe / one-off mood / self-induced / positive confirmation — each its own weight) before ADD/UPDATE/UPVOTE/DOWNVOTE, promotes at weight ≥3.0 into hooks or regression checks, and applies an asymmetric trust gate when *consuming* a lesson: an added suggestion needs a citation, a blocked one needs an anchor (a rule conflict, a weight ≥3.0 lesson, or a deterministic check) — a soft match is surfaced to you, never auto-applied. Top-3 lessons injected each session. |
| **Self-maintenance** | `/harness-audit` reads a living per-project `references/baseline.md` first (source-of-truth table, wiring seams, known gotchas, a change log it appends to every run), then fixes mechanical invariants in-pass — including an issues-solved numbering-collision lint, a `plans/` archival check, and a generic state-file seam-check (every `state/` writer needs a reader). A regression-eval folder turns every confirmed failure into a permanent runnable check; `loop.md` routes bare `/loop` through finish-work → learn → audit → next task. |
| **Review & cleanup** | `/senior-review` — a holistic, read-only 4-section review (security, performance, code quality, production readiness), distinct from `/harness-audit` (which only covers `.claude/` itself). `/declutter` — discovers dead-code/dependency/duplicate candidates, then verifies each one empirically in its own parallel agent (no name/comment taken on trust), reporting four buckets: confirmed-dead, trap (looked dead, isn't), promote-candidate (consolidate, don't delete), needs-your-call. Nothing is removed without evidence. |
| **Small-model elevation** | `Explore` pinned to Haiku; `small-executor` (one narrow step, persistent project memory, prompt-hook completion gate); `small-verifier` (single-aspect checklists); `elevate.js` workflow (attempt → 3-aspect verifier panel → one evidence-injected retry → escalate). |
| **Safety & housekeeping hooks** | Deterministic, fixture-tested gates: protected files/lockfiles, secret scanning (ask, not deny), dangerous-command blocking (force-push, rm -rf, curl\|sh, un-dry-run publish), with a hook test harness and block-path coverage enforced by a regression check. Plus quiet housekeeping: session-end/pre-compact activity-log snapshots, frontmatter date bumps on edit, and a reminder toward `issues-solved/` after repeated edits to the same file (a debug-signature heuristic). |
| **Live status** | `statusline.sh` shows build/test health and running/broken task counts, plus two signals that only appear when there's something to act on: a lesson-promotion-pending count and a context-budget warning. |
| **Durable knowledge zones** | `memory/`, `issues-solved/`, `tasks/`, `agent-memory/`, and `plans/<slug>` for design work bigger than one `TASKS.md` line (single-file by default, archived once shipped, checked by `/harness-audit`). |
| **The management system** | `.claude/GUIDE.md` — five-zone file classification, placement decision tree, who-writes-what permission matrix, lifecycle rules, context-economy budgets (incl. path-scoped rules), and an operating protocol for small models. |

All design choices are evidence-backed; the research digests (with citations) ship into every project at `.claude/memory/research/`.

## Install

Inside Claude Code, run:

```
/plugin marketplace add Aditya-Nagariya/harness-forge
/plugin install forge@harness-forge
```

Then, in any project of yours, run `/forge` — it scans the stack, proposes a plan, installs the harness, and verifies it.

**Prerequisites:** `python3` (always used by the hooks) and `jq` (only for the hook test suite). Hooks fail open if `python3` is missing, so nothing breaks, but the self-healing and live-status features need it.

## Use

- `/forge` — auto-detects: fresh install (scan → plan table → confirm → apply → verify) or upgrade.
- `/forge doctor` — validate the installed harness; report `.forge-new` merge conflicts; fix mechanical issues.
- Installed skills: `/ship` `/fix-issue` `/milestone-task` `/catchup` `/learn` `/harness-audit` `/context-budget` `/declutter` `/senior-review`.
- Installed output styles (opt-in): `/output-style terse` for compressed responses, `/output-style "Reality-Check Senior"` for an anti-sycophancy persona.

## Updating

When a new version ships, pull it with:

```
/plugin marketplace update harness-forge
/plugin update forge
```

Then run `/forge` in a project to upgrade its installed harness in place — pristine files update automatically, your edits are preserved as `<file>.forge-new`, and your data (lessons, memory, tasks, issues, plans, `harness.env`, `CLAUDE.md`) is never touched.

**Upgrade safety:** `bootstrap.sh` records a sha256 manifest of every installed harness file. On upgrade, pristine files update automatically; files you've modified are never clobbered — the new version arrives as `<file>.forge-new`. The one exception is `settings.json`: a user-modified copy gets a JSON-aware merge instead (hooks arrays are concatenated and deduped by matcher+command, so your own hook survives alongside newly-added template hooks), falling back to `.forge-new` only on a genuine non-array conflict. Your data (lessons, memory, tasks, issues, `harness.env`, `CLAUDE.md`, `plans/`) is never touched by an upgrade, ever.

## Layout

```
plugins/forge/skills/forge/
├── SKILL.md              # the /forge command (create / upgrade / doctor)
├── GUIDE.md → templates/GUIDE.md   # installed into every project as .claude/GUIDE.md
├── scripts/
│   ├── bootstrap.sh      # deterministic install/upgrade with hash-manifest safety
│   └── validate.sh       # mechanical-invariant verification
└── templates/            # the harness payload (stack-agnostic; configured via .claude/harness.env)
```

Stack specifics (build/test/lint/format commands, protected dirs, lockfiles) live in one generated file — `.claude/harness.env` — so hooks are byte-identical across stacks and upgrades never conflict with your configuration.
