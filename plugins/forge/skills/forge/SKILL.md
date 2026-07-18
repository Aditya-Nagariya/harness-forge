---
name: forge
description: "Create or upgrade a self-improving Claude Code harness in the current project — self-healing failure ledger, per-file lesson memory, regression evals, small-model elevation agents, deterministic safety hooks. Modes: (no args) auto-detect new vs upgrade; 'doctor' = validate only. Evidence-gated: scan, propose plan, confirm, apply, verify."
argument-hint: "[doctor]"
disable-model-invocation: true
allowed-tools: "Bash(bash ${CLAUDE_SKILL_DIR}/scripts/*.sh *), Bash(bash .claude/scripts/self-check.sh), Bash(bash .claude/hooks/*.sh), Read, Grep, Glob"
---

You are installing, upgrading, or checking the self-improving harness. The governing principle (from the evidence-gated-installer pattern): **install nothing without evidence and consent — when in doubt, leave it out; unused config costs tokens and trust forever.**

Everything deterministic is done by the bundled scripts — never hand-copy template files:
- `${CLAUDE_SKILL_DIR}/scripts/bootstrap.sh --target DIR --set KEY=VALUE ... --house-rules FILE` — installs/upgrades (auto-detects mode from the target's `forge-manifest.json`; upgrade never touches user data and never clobbers user-modified harness files — those get a `.forge-new` alongside).
- `${CLAUDE_SKILL_DIR}/scripts/validate.sh --target DIR` — verifies every mechanical invariant.
- Reference docs in this skill's folder: `GUIDE.md` (the management system installed into every project), `templates/` (what gets installed).

## Mode: doctor ($ARGUMENTS contains "doctor")

Run `validate.sh --target .` and report. If it fails, fix mechanical issues (exec bits, broken JSON) directly and re-run; propose (don't apply) anything judgment-level. Also list any `*.forge-new` files awaiting merge from a previous upgrade. Stop after reporting — doctor never installs.

## Mode: create / upgrade (default)

### Phase 1 — Read-only scan (no writes)

1. Detect existing install: does `.claude/forge-manifest.json` exist? → upgrade path (reuse its recorded `substitutions` as defaults; only re-ask what's missing or changed).
2. Detect the stack from real evidence: manifests (`package.json`, `Cargo.toml`, `pyproject.toml`, `go.mod`, `Gemfile`, `pom.xml`, `Makefile`...), CI configs, existing scripts. Derive candidates for: BUILD_CMD, TEST_CMD (narrowest fast variant), LINT_CMD, FMT_CMD, SRC_EXTS, PROTECTED_DIRS (real source roots only), LOCKFILES (present ones), FINGERPRINT_FILES (the manifests you found), GRAPH_CMD (only if a graph tool is actually installed — verify with `command -v`, else empty).
3. Read 3–5 real source files to extract 3–6 **house rules** — actual conventions of this codebase (error-handling idiom, forbidden patterns, layering rules), not generic advice. These fill `{{HOUSE_RULES}}` in the executor/verifier agents and CLAUDE.md.
4. Check for content to migrate: existing `CLAUDE.md` (will NOT be overwritten — note additions to propose), `.cursorrules`/`AGENTS.md` (propose folding into house rules).

### Phase 2 — The plan table (the contract)

Present exactly what will happen — a table of: component → action (install / update-pristine / conflict-expected / preserve) — plus the derived `harness.env` values and the drafted house rules. Ask the user to confirm or amend via AskUserQuestion (one round; offer Minimal — hooks+memory+GUIDE only — vs Full — everything including agents/workflows).

### Phase 3 — Apply

Write the confirmed house rules to a temp file, then run `bootstrap.sh` with the confirmed `--set` values. Never edit template files in `${CLAUDE_SKILL_DIR}` — they belong to the plugin.

### Phase 4 — Verify (mandatory, not optional)

1. `validate.sh --target .` must pass — fix and re-run until it does or report exactly what's failing.
2. Positively test one gate's block path: `echo '{"tool_input":{"command":"git push --force origin main"}}' | bash .claude/hooks/block-dangerous-commands.sh` must exit 2 (a gate whose failure mode is "silently allow" must be demonstrated to fire, never assumed).
3. If upgrading: list every `.forge-new` conflict and offer to merge each one (show the diff, let the user decide).

### Phase 4.5 — Unattended loop (optional, ask first)

Only on a fresh install (not every upgrade): ask the user via AskUserQuestion whether to set up unattended background maintenance — `/loop` running on an OS-level schedule (launchd on macOS, cron on Linux) even when no Claude Code session is open, doing real work but never auto-committing (results land in `.claude/state/unattended-runs/` for review). Default answer if asked generically: recommend yes on a solo/personal project, since it's the only way `/loop` runs when nobody's around to invoke it manually.

If confirmed: ask for an interval in hours (suggest 6 as a default), then run `bash .claude/scripts/setup-unattended-loop.sh <hours> install` and report the result verbatim (which OS mechanism it used, where the entry lives). If declined or the platform isn't macOS/Linux, skip silently — this step is never required.

### Phase 5 — Report

Summarize: installed/updated/preserved/conflicts, the harness.env values, where the management guide lives (`.claude/GUIDE.md`), and the three commands the user should know: `/learn`, `/harness-audit`, `/ship`, and whether unattended background maintenance is running (Phase 4.5). Remind: restart the session (or start a new one) so SessionStart hooks and new agents load.
