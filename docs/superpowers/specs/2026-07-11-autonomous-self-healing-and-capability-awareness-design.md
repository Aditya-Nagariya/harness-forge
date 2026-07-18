Status: draft

# Autonomous self-healing + capability awareness (harness-forge ROADMAP R1 + R10)

## Problem

Two ROADMAP.md items turned out to be one problem:

- **R1** — the harness's self-healing loop (`loop.md`, chaining finish-work → `/learn` → `/harness-audit` → next task) only runs when a human remembers to type `/loop`. Nothing learns from a mistake until explicitly told.
- **R10** — the model isn't reliably aware of everything available to it (skills, MCP tools, harness mechanisms), so it under-uses its own capability. Flagged in the ROADMAP as an open research question, not a spec'd feature.

R1's reliability is bottlenecked by R10: any purely advisory trigger for `/loop` (a context-injected nudge at session start) has the same weakness this harness's own `/learn` design already names as its reason for preferring hooks over prose — "hooks get ~100% compliance; advisory rules get 70–90% and dilute each other." A nudge that competes for attention in context, especially across a compaction boundary, is not "truly autonomous" — it's a nudge that can be silently ignored indefinitely. Both problems reduce to the same fix: convert an advisory reminder into a deterministic, hook-enforced condition.

## Decisions (resolved via brainstorming Q&A)

| Decision | Choice | Why |
|---|---|---|
| R1 scope | Full `/loop` (not just `/learn`) | User's explicit choice — the whole maintenance chain should trigger, not just failure-to-lesson conversion. |
| Trigger tiers | Both: session-bound (Tier 1, always on) + OS-level unattended (Tier 2, opt-in) | Session-bound needs no setup and has no new autonomy risk; OS-level is the only way to get genuine "ran while I wasn't at my computer" behavior. |
| Unattended commits | Never auto-commit | Nobody is watching in real time during an unattended run; leave the diff + a summary for human review next session instead of letting code land in git history unreviewed. |
| Tier 2 default | Opt-in during `/forge` install | Writing to the OS scheduler is a bigger, more persistent footprint change than anything else `/forge` does today (everything else stays inside `.claude/`). |
| Tier 2 install mechanism | Agent runs it after explicit confirmation | Same confirm-then-act pattern Claude Code already uses for every other risky action — smoother than printing instructions for the user to run manually, still never silent. |
| R1+R10 spec scope | One combined spec | They share the same enforcement mechanism; designing them separately would duplicate it. |
| Enforcement model | Hard gate, no soft phase | User's explicit choice over the initially-recommended graduated (soft-then-hard) model — every session, the first source edit is blocked until both conditions are satisfied. |
| Skill-search tool | ~~claude-skills-mcp~~ → **SkillSeek** (see Correction below) | Better fit and avoids a dependency on a maintainer-declared-dead project. |

### Correction: claude-skills-mcp is deprecated

The brainstorming session initially settled on `claude-skills-mcp` (K-Dense-AI) for R10's search mechanism. Verifying it before writing this spec found its own README states: *"This MCP server is no longer hosted or maintained... there is no longer a need for an MCP bridge to deliver skills to your coding assistant."* Even when live, its default config searched a curated external catalog (Anthropic's official skills + K-Dense's scientific skills), not a user's own locally-installed project skills — the wrong shape for R10 regardless of maintenance status.

**Replacement: [SkillSeek](https://github.com/TheQmaks/skillseek)** — indexes every locally-installed skill (including plugin-bundled ones) via BM25, exposes an MCP tool (`skill_search`), a CLI (`skillseek search`), and ships its own `SessionStart`+`UserPromptSubmit` hooks that already do exactly the "nudge to search" behavior this spec was about to design from scratch. It independently names the same problem this spec is solving (`skillListingBudgetFraction` caps skill listing at ~1% of the context window — enough for 60–80 of Claude Code's 1700+ skills, not all of them).

**Risk, and how the design handles it:** SkillSeek is very new (0 GitHub stars at the time of writing — essentially unproven, single-maintainer, no track record). harness-forge must not take a hard dependency on it for a core gate. **Resolution: the gate fails open if SkillSeek isn't installed** — its "was a search performed this session" condition is treated as automatically satisfied when SkillSeek's index file doesn't exist, so the harness behaves exactly as it does today for anyone who hasn't opted into SkillSeek, and gets the enhanced behavior only for those who have. harness-forge documents SkillSeek as a recommended companion install, never bundles or auto-installs it.

## Design

### Architecture

```
SessionStart (session-start.sh, extended)          PreToolUse (capability-gate.sh, NEW)
  └─ clears two session flags:                        matcher: Write|Edit
     .gate-checked-this-session                        └─ non-source path (.claude/, etc.)?
     .skillseek-used-this-session                          → exit 0, not gated
  └─ (existing: health/task context,                  └─ .gate-checked-this-session set?
     now also: N unattended runs                          → exit 0, already satisfied
     awaiting review)                                 └─ else check both conditions:
                                                            (a) /loop not overdue
PostToolUse (NEW entry, matcher:                           (b) skillseek used this session,
  mcp__skillseek__skill_search)                                OR skillseek not installed
  └─ touches .skillseek-used-this-session                 → both satisfied: set flag, exit 0
                                                            → either fails: deny, telling the
loop.md (extended)                                             model exactly what to run
  └─ final step: run scripts/record-loop-run.sh
     to stamp .claude/state/last-loop-run.json         Tier 2 (opt-in, scripts/setup-unattended-loop.sh)
  └─ FORGE_UNATTENDED branch: skip /ship's                └─ launchd (macOS) or cron (Linux) entry
     commit step, write a run summary instead                runs: FORGE_UNATTENDED=1 claude -p "/loop"
                                                            └─ output logged to
                                                               .claude/state/unattended-runs/<ts>.log
```

### Why the matcher exclusion matters (anti-deadlock)

The gate's `Write|Edit` matcher only applies to real source paths — anything under `.claude/` is excluded. Without this, `/loop`'s own first action (`/learn` writing a lesson file under `.claude/memory/lessons/`) would itself trip the gate before `/loop` could ever satisfy it — a self-inflicted deadlock, not a safety feature.

### Why "deny" and not "ask"

The gate uses `permissionDecision: deny`, not `ask`. An `ask` decision requires human confirmation — which would hang forever during an unattended Tier 2 run, where nobody is present to confirm. `deny` with a clear reason lets the model resolve the block itself (run `/loop`, or call `skill_search`) whether a human is watching or not.

### Fresh-install grace period

A brand-new install has no `last-loop-run.json`, which would otherwise read as "infinitely overdue" and block the very first edit. `bootstrap.sh` pre-seeds this file with the install timestamp, so the overdue clock starts from install time, not from absolute zero.

### State files

- `.claude/state/last-loop-run.json` — `{"last_run": "<ISO8601>"}`. Written by `scripts/record-loop-run.sh`, called as `/loop`'s final step. Seeded at install by `bootstrap.sh`.
- `.claude/state/.gate-checked-this-session` — empty marker file. Set by `capability-gate.sh` once both conditions are satisfied; cleared by `session-start.sh`.
- `.claude/state/.skillseek-used-this-session` — empty marker file. Set by a new `PostToolUse` hook entry matching SkillSeek's MCP tool; cleared by `session-start.sh`.
- `.claude/state/unattended-runs/<timestamp>-summary.md` — written by `/loop` under `FORGE_UNATTENDED=1` instead of committing.

### New config (`harness.env`)

- `LOOP_OVERDUE_HOURS` (default `24`) — hours since `last_run` before the gate's condition (a) fails.

### Testing

- Hook fixtures for `capability-gate.sh` (`hooks/tests/fixtures/capability-gate/*.json`): allow on non-source path regardless of overdue state; deny when overdue and gate not yet checked; deny when SkillSeek installed but not yet searched; allow once `.gate-checked-this-session` is set; allow when SkillSeek not installed (fail-open).
- A regression check asserting the gate's matcher never fires on `.claude/` paths (the anti-deadlock property), following the existing `evals/regressions/NNNN-*.sh` convention.
- Manual scratch-directory verification of `setup-unattended-loop.sh` on macOS (launchd) given the reference machine is Darwin; cron path documented but not machine-verified here.

## Out of scope (for this spec)

- Building SkillSeek itself, or auditing its BM25 implementation — harness-forge only checks for its presence and documents it as a recommended companion.
- Windows Task Scheduler support for Tier 2 (documented as a follow-up, not blocking this spec).
- Any change to `/loop`'s own step logic (finish-work → learn → audit → next task) — only what triggers it changes.
