# Roadmap

The requirements below are the maintainer's next-phase wish list for harness-forge, cleaned up from raw notes into independent, self-contained write-ups. Each section stands alone on purpose: if you want to contribute, pick one section, read only that section, and you should know exactly what's being asked, why, and what's already been researched — without needing the rest of this file for context.

**Status: proposed** on every item unless noted otherwise (R1 and R10 are done — see those sections). Where a section says "open question," that's a real fork the maintainer hasn't resolved yet — raise it in your PR/issue rather than guessing.

---

## R1 — Autonomous self-healing loop (stop requiring `/learn` by hand) — ✅ Done (forge 1.5.1)

**Problem.** The harness's self-healing design (failure ledger → `/learn` → promoted lessons) only closes the loop if someone remembers to run `/learn`. Today nothing gets learned from a mistake until a human explicitly points it out and invokes the skill.

**What shipped.** The open question below resolved to "mostly inside the harness, plus an opt-in outside-the-harness layer for the unattended case" — both halves exist now:

- **`hooks/capability-gate.sh`** (PreToolUse, `Write|Edit`) hard-blocks the first real source-code edit of a session until `.claude/state/last-loop-run.json` shows `/loop` ran within `LOOP_OVERDUE_HOURS` (default 24h; never gates `.claude/` paths, so `/loop`'s own maintenance writes can't deadlock against it). This replaced an earlier advisory-nudge design — deterministic hooks get ~100% compliance, prose nudges don't, and this was verified directly: a real headless Haiku session hit the deny, read `GUIDE.md`/`loop.md` on its own, ran the fix, and succeeded, with zero coaching.
- **A real installed `/loop` skill** (`skills/loop/SKILL.md`) wrapping `loop.md` — added in 1.5.1 after a stress-test run showed the gate's original deny message pointed at a slash command that didn't exist yet in forged projects, and the target small model bypassed the gate via a Bash heredoc instead of running maintenance.
- **`loop.md` Step 0** stamps the timestamp at the *start* of a loop iteration (not just the end), fixing a self-deadlock a whole-branch review caught: `/loop`'s own in-flight-work/idle-task steps can themselves be source edits, which the gate would otherwise block before `/loop` could ever satisfy it.
- **Tier 2 — `scripts/setup-unattended-loop.sh`**, opt-in via `/forge`'s Phase 4.5 (explicit confirmation, never silent): installs a launchd (macOS) or cron (Linux) entry running `FORGE_UNATTENDED=1 claude -p "/loop"` on an interval. Under that env var, `/loop` skips `/ship`'s commit/push steps entirely and writes a timestamped review summary instead — verified with a real unattended run, which (working as intended) found and reported a real bug in the harness's own audit wiring.

**How it was verified.** Design → spec → 12-task implementation plan → subagent-driven build with per-task review → two rounds of whole-branch review (caught the Step 0 deadlock) → a real stress-test battery (4 headless sessions against forged scratch projects, plus a 1.4.0→1.5.x upgrade test) that found 2 more real gaps (the missing `/loop` skill, and R10's stale-index deadlock below) before those were fixed and re-verified live.

**Known remaining limit.** The gate only matches the `Write`/`Edit` tool names — a model can still route around it via `Bash` (observed once, before the `/loop` skill existed, on a small model; not observed after the fix, but the primitive gap remains). Unattended-mode-on-a-small-model is untested (the real unattended run used a stronger default model).

---

## R2 — Complexity-based task routing, inspired by Ruflo (top priority)

**Problem.** Flagged by the maintainer as the single most important item here: auto-route a task to a cheaper/faster model or a stronger one based on how hard the task actually is, instead of a flat default for everything.

**Correction worth flagging.** The original notes linked `github.com/revfactory/harness` next to the word "Ruflo," but these are two different projects. `revfactory/harness` is a "team-architecture factory" — turns a domain description into a generated multi-agent team using 6 architecture patterns; it does not do complexity-based routing. The actual Ruflo is [`ruvnet/ruflo`](https://github.com/ruvnet/ruflo) (formerly Claude-Flow) — a large multi-agent meta-harness (98 agents, 60+ commands, its own MCP server and daemon) whose **Router** component auto-routes tasks by complexity and whose **Learning Loop** captures successful trajectories to route future similar tasks better over time.

**Proposed approach.** harness-forge already has a starting point: `elevate.js`'s attempt → 3-aspect verifier panel → evidence-injected retry → escalate cascade. Extend it with an explicit difficulty-classification step *before* the first attempt (a cheap heuristic, or a small-model triage call) so routing is decided up front instead of only reactively escalating after a verifier rejects. Given harness-forge's zero-dependency, single-plugin philosophy, the recommendation is to **adopt Ruflo's routing concept, not the framework itself** — Ruflo is a much heavier dependency (its own daemon/MCP server/98 agents) than harness-forge's current scope.

**Open question.** Confirm with the maintainer whether "adopt the concept into `elevate.js`" is the right call, or whether an actual Ruflo integration/companion plugin is wanted instead.

---

## R3 — `/forge` should detect and offer to upgrade an existing harness, never blindly overwrite

**Problem.** If a project already has *some* Claude Code setup — forge-installed or hand-rolled — running `/forge` should never destroy it and rebuild from scratch.

**Current state.** `/forge` already has a safe upgrade path for its *own* prior installs (sha256 manifest, `.forge-new` conflict files for user-modified harness code). The gap is detecting a **non-forge** `.claude/` — one built by hand, or by a different plugin — and offering a merge/adopt path instead of either overwriting it or refusing to run.

**Proposed approach.** Before the fresh-install branch runs, scan for an existing `.claude/` with no `forge-manifest.json`. If found, surface what's actually there (skills/hooks/agents by name) and ask whether to (a) adopt it as the baseline and layer forge's additions in without touching existing files, (b) install alongside for manual review, or (c) abort.

---

## R4 — Deeper, first-principles study of harness sources — including newly added, unmined material

**Problem.** The harnesses studied so far were mined at a fairly surface, pattern-matching level. The maintainer wants a first-principles pass, and has since added more source material that hasn't been touched by any research session yet.

**Confirmed unmined sources** (found under `example_harness/` on the maintainer's machine, not yet in this repo):
- `loop-engineering-main/` — a substantial project (its own `CONTRIBUTING.md`, `patterns/`, `examples/`, `starters/`, `skills/`, a `loop-init`/`loop-audit`/`loop-cost`/`loop-sync`/`loop-context` npm toolchain, and a "Loop Ready" scoring system). Directly relevant to R1's self-healing-loop gap and R10 below.
- Two research write-ups: *"From Agent Loops to Structured Graphs: A Scheduler-Theoretic Framework for LLM Agent Execution"* and *"The 3 AI Loops Worth Stealing."*

**Proposed approach.** A dedicated research pass — matching the depth of the earlier multi-agent research fan-out that produced this harness's existing feature set — specifically over `loop-engineering-main` and the two articles, since they bear directly on R1 and R10.

---

## R5 — Bundle general-purpose tools/plugins into the harness by default

**Problem.** The maintainer wants a small set of generally-useful tools installed by default rather than left for each user to discover on their own: a dependency/architecture graph tool ("graphify"), a code-review graph tool, a Ruff-based import checker/cache, Context7 (documentation-context MCP server), and similar.

**Proposed approach.** Treat each as an optional-but-recommended default in `/forge`'s install plan — surfaced during the scan/plan step, on by default, opt-out rather than opt-in. Each named tool needs its own quick research pass (current maintenance status, exact install footprint, license) before it's safe to turn on by default.

---

## R6 — First-class Ruff support for Python projects

**Problem.** Wants `ruff format`, `ruff check --statistics`, and `ruff check --fix .` wired in as the standard lint/format toolchain for Python projects.

**Proposed approach.** Add Ruff as a first-class, pre-filled option when `/forge`'s stack-detection step identifies a Python project — populating `LINT_CMD`/`FMT_CMD` in `harness.env` accordingly. This is a small, self-contained change consistent with the existing stack-agnostic, `harness.env`-driven hook design (hooks stay byte-identical across stacks; only the env file changes).

---

## R7 — Hard code-quality score gate, auto-fix until threshold

**Problem.** Wants a numeric quality bar the harness actively fixes toward, not just reports: pylint score ≥ 9 via `python -m pylint --recursive=y . --max-line-length=200` (excluding venv, tests, and generated/node files — core logic only).

**Proposed approach.** Generalize as an optional quality-score gate alongside the existing `$BUILD_CMD`/`$TEST_CMD`/`$LINT_CMD` — a `$QUALITY_CMD` + `$QUALITY_THRESHOLD` pair in `harness.env`, with pylint as the reference implementation for Python and a documented pattern for wiring an equivalent gate for other stacks. Should reuse the fix-until-verified loop shape already present in `/senior-review` and `/declutter` rather than inventing a new one.

---

## R8 — Skill-discovery MCP integration

**Problem.** Wants a mechanism for Claude to actively search for/discover relevant skills for a task, rather than relying on the model already knowing every installed skill exists.

**Research so far.** Real, existing tools already do this: [`K-Dense-AI/claude-skills-mcp`](https://github.com/K-Dense-AI/claude-skills-mcp) (vector/semantic search over installed skills, plus a `list_skills` inventory tool), `SkillSeek` (BM25 index over installed skills, exposed via CLI/MCP/hooks), and several listings on `mcpmarket.com/tools/skills/*`. None have been evaluated hands-on yet.

**Proposed approach.** Trial one — `claude-skills-mcp` looks like the closest fit given it exposes both semantic search and a full inventory listing — against harness-forge's own installed skill set, then decide whether to recommend it as an optional default during `/forge` install.

---

## R9 — An explicit protocol for two independent parallel features in one repo

**Problem.** Wants a clean, documented way to work two unrelated features in parallel in the same repo via git worktree, then merge both back and tear down the worktrees gracefully, without conflicts.

**Current state.** This is already substantially covered by two existing mechanisms: Claude Code's native `EnterWorktree`/`ExitWorktree` tools, and harness-forge's own `Workflow` tool (`isolation: 'worktree'` per-agent) plus the `.worktreeinclude` file already shipped in templates.

**Proposed approach.** Rather than new low-level machinery, this likely wants a **skill** that packages the specific protocol — spin up two worktrees, work each independently, merge both back cleanly, remove both worktrees — as a named, repeatable procedure. The primitives exist; there's no documented one-command way to run the common case end to end.

---

## R10 — "Live" awareness of the model's full toolset — ✅ Done for the skill-discovery slice (forge 1.5.1); broader question still open

**Problem, in the maintainer's own framing:** the model isn't reliably aware of everything available to it — skills, MCP tools, harness mechanisms — so it under-uses its own capability. Originally flagged as unsolved, not a spec'd feature: *"I don't know how we'll do this, but we need to brainstorm it."*

**What actually shipped — narrower than the original framing, and that narrowing was deliberate.** Brainstorming this alongside R1 surfaced that R10 wasn't really a separate open question — R1's own trigger (an advisory "please run `/loop`" nudge) had the exact same weak-compliance failure mode R10 was worried about in general. So R10 got scoped down to the one slice that was both actionable and load-bearing for R1: *does the model know to search for a relevant installed skill before assuming one doesn't exist.* `capability-gate.sh`'s second condition requires a [SkillSeek](https://github.com/TheQmaks/skillseek) `skill_search` call once per session (only if SkillSeek's index is actually present — the harness never bundles or installs it) before source edits proceed, replacing a from-scratch design with an existing, purpose-built tool (its own README independently cites the same root problem: Claude Code's `skillListingBudgetFraction` caps skill listing at ~1% of context, hiding most of a large plugin set).

**A real deadlock was found and fixed here too.** A stress test proved the original design's "fails open if SkillSeek isn't installed" claim was wrong in one case: if SkillSeek's index file exists but the plugin itself was later uninstalled, a session hard-deadlocked with no escape (reproduced: 20 turns, task failure). Fixed with a one-shot safety valve (`.skillseek-denied-once`) — the SkillSeek condition now blocks at most once per session; a working setup behaves identically to before, a broken one costs one retry instead of total failure. The `/loop`-overdue condition was deliberately *not* softened the same way (verified by a control test) — its remedy always exists in the project, so a hard gate there is safe.

**Still open, not addressed by the above.** The original, broader ambition — awareness of *all* installed skills, MCP tools, and harness mechanisms, not just "search before assuming a skill doesn't exist" — remains unsolved, along with the context-compaction-degrades-pointers half of the original framing. R4's `loop-engineering-main` research (its "Loop Ready" scoring, five-building-blocks framing) is still unmined and may bear on this larger question; treat this section as re-opened at that broader scope if someone wants to pursue it.

---

## R11 — Rate-limit-aware graceful pause and resume

**Problem.** Wants live session/weekly usage-remaining data fed to Claude so it can proactively wrap up before hitting a hard cutoff — pausing gracefully and saving exact state for a clean resume, instead of a response cutting off mid-work.

**Why it matters (maintainer's own reasoning).** Two benefits: work doesn't break mid-edit because the model ran out of room to finish, and the available budget gets used efficiently instead of wasted by finishing too early out of caution.

**Proposed approach.** Needs research into whether Claude Code exposes remaining session/weekly usage to a hook or the statusline today. If so, wire it into `session-start.sh` and/or the statusline, and add a rule instructing the model to checkpoint (commit, update `TASKS.md` status, note the exact next step) once usage crosses a threshold — rather than continuing until forcibly cut off.

---

## R12 — Adopt Karpathy's "Think Before Coding" + "Surgical Changes" as new house rules; explicitly skip the rest (priority: 3rd)

**Problem.** [multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills) packages four LLM-coding-discipline principles (derived from Andrej Karpathy's public observations, not authored by him) into a single `CLAUDE.md` file: Think Before Coding, Simplicity First, Surgical Changes, Goal-Driven Execution.

**Correction worth flagging.** Despite the repo's name, this is not Claude Code Skills in the SKILL.md/progressive-disclosure sense — it's one `CLAUDE.md` content file (optionally installed as a plugin purely for cross-project reuse; no skill-loading mechanics involved).

**What's actually new here — checked against what's already enforced, not assumed.** Read the source file directly, then grepped this harness's own templates for each principle before claiming coverage:
- **Simplicity First** — already Claude Code's own base-system-prompt behavior, near-verbatim ("don't add features/abstractions beyond what the task requires... three similar lines is better than a premature abstraction"). Adding it again here would just duplicate the model's own base instructions.
- **Goal-Driven Execution** (verifiable success criteria, TDD, loop-until-verified) — already this harness's central thesis, and more rigorously enforced than the source repo's version: `rules/ship-verification.md` requires a stated verification command + observed result before any task can be marked `completed`, and `/milestone-task` already runs a red-green-refactor TDD loop.
- **Surgical Changes** (touch only what you must, don't refactor adjacent code, clean up only your own mess) — checked `rules/git-workflow.md` directly: it covers branch naming, commit format, and push safety only — nothing about edit scope. **Genuinely not covered.**
- **Think Before Coding** (state assumptions explicitly, present interpretations when genuinely ambiguous, push back, stop and name confusion rather than guess) — grepped `CLAUDE.md.tmpl` and `GUIDE.md` for "assumption"/"clarif"/"push back"/"confused": zero hits. **Genuinely not covered.**

**Proposed approach.** Do not bulk-import the source `CLAUDE.md` — it would duplicate 2 of 4 principles for zero new value, burning context budget against this harness's own evidence-based context-economy stance (see R13). Add only the two genuinely uncovered principles — Think Before Coding, Surgical Changes — as new house-rule content, written in harness-forge's own voice rather than copy-pasted, either as new `CLAUDE.md.tmpl` bullets or a short new `rules/` file.

---

## R13 — A repeatable discipline for evaluating external CLAUDE.md/prompt-guideline repos before adopting them (priority: 4th)

**Problem.** R12 above is a one-time action. More "prompt improvement" repos like it will keep surfacing, and the default temptation each time will be to bulk-install whatever looks good — which is exactly how this harness's own context budget got blown once already (`IMPROVEMENT-STUDY.md`'s Part A finding: ~5× over the evidence-based budget from accreted always-loaded prose). There's no documented process for vetting one of these before adding it.

**Proposed approach.** Formalize the diff-against-existing-coverage analysis R12 itself demonstrates as a repeatable step — likely inside `/forge`'s Phase 1 house-rules drafting, or as a `/harness-audit` check: before adopting any external `CLAUDE.md`/rule-collection wholesale, diff its claims against (a) Claude Code's own base system prompt and (b) this harness's existing `rules/*.md`, and only add the genuinely non-redundant delta. Reject-by-default is the safe posture, given this harness's own founding evidence that instruction-following decays as rule count grows (IFScale, arXiv:2507.11538).

**Open question.** Should this live as a documented step inside an existing skill (`/forge`'s house-rules phase seems the most natural home), or as its own lightweight new skill (e.g. `/evaluate-guidelines`)?

---

## Contributing

Pick a section above, comment on (or open) the corresponding issue to claim it, and scope your PR to that section alone — these are intentionally independent so review stays small and focused. If a section's "open question" isn't resolved yet, raise it before writing code; several of these have a real fork in approach that changes the implementation significantly.
