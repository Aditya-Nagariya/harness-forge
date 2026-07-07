# harness-forge

One slash command that installs — and later upgrades — a **self-improving Claude Code harness** in any project. The harness it forges makes agents (including small/fast models like Haiku) safer, cheaper, and measurably more reliable, and it gets better over time by converting its own failures into durable, promoted rules.

## What the forged harness contains

| Layer | Mechanism |
|---|---|
| **Self-healing** | Every tool failure is auto-recorded with a normalized signature (`capture-failure.sh` → machine-local ledger); repeats surface at session start with a prompt to convert them into lessons. |
| **Continuous learning** | Per-file lesson store with trigger conditions, verbatim evidence, and a vote lifecycle (`/learn`: retrieve-before-write, delta-only updates, promotion at weight ≥3.0 into hooks or regression checks — mechanized rules get ~100% compliance vs ~70–90% for prose). Top-3 lessons injected each session. |
| **Self-maintenance** | `/harness-audit` (mechanical invariants fixed in-pass), a regression-eval folder where every confirmed failure becomes a permanent runnable check, and a `loop.md` that routes bare `/loop` through finish-work → learn → audit → next task. |
| **Small-model elevation** | `Explore` pinned to Haiku; `small-executor` (one narrow step, persistent project memory, prompt-hook completion gate); `small-verifier` (single-aspect checklists); `elevate.js` workflow (attempt → 3-aspect verifier panel → one evidence-injected retry → escalate). |
| **Safety hooks** | Deterministic, fixture-tested gates: protected files/lockfiles, secret scanning (ask, not deny), dangerous-command blocking (force-push, rm -rf, curl\|sh, un-dry-run publish), with a hook test harness and block-path coverage enforced by a regression check. |
| **The management system** | `.claude/GUIDE.md` — four-zone file classification, placement decision tree, who-writes-what permission matrix, lifecycle rules, context-economy budgets, and an operating protocol for small models. |

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

## Updating

When a new version ships, pull it with:

```
/plugin marketplace update harness-forge
/plugin update forge
```

Then run `/forge` in a project to upgrade its installed harness in place — pristine files update automatically, your edits are preserved as `<file>.forge-new`, and your data (lessons, memory, tasks, issues, `harness.env`, `CLAUDE.md`) is never touched.

**Upgrade safety:** `bootstrap.sh` records a sha256 manifest of every installed harness file. On upgrade, pristine files update automatically; files you've modified are never clobbered — the new version arrives as `<file>.forge-new`. Your data (lessons, memory, tasks, issues, `harness.env`, `CLAUDE.md`) is never touched by an upgrade, ever.

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
