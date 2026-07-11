# Roadmap

The requirements below are the maintainer's next-phase wish list for harness-forge, cleaned up from raw notes into independent, self-contained write-ups. Each section stands alone on purpose: if you want to contribute, pick one section, read only that section, and you should know exactly what's being asked, why, and what's already been researched — without needing the rest of this file for context.

None of these are started. **Status: proposed** on every item unless noted otherwise. Where a section says "open question," that's a real fork the maintainer hasn't resolved yet — raise it in your PR/issue rather than guessing.

---

## R1 — Autonomous self-healing loop (stop requiring `/learn` by hand)

**Problem.** The harness's self-healing design (failure ledger → `/learn` → promoted lessons) only closes the loop if someone remembers to run `/learn`. Today nothing gets learned from a mistake until a human explicitly points it out and invokes the skill.

**Proposed approach.** Add a scheduled or automatic trigger for `/learn` (and `/harness-audit`) instead of relying purely on manual invocation — e.g. auto-run at natural checkpoints (session start, if enough time/turns have passed since the last run) plus, where the platform allows it, a real interval-based background trigger.

**Research so far.** Claude Code exposes a native cron-style scheduling primitive (`CronCreate`/`CronList`), but it is explicitly **session-scoped and non-durable**: jobs live only in memory for the current session, auto-expire after 7 days even if the session stays open, and vanish entirely the moment the session ends. It cannot by itself deliver "learns even when nobody's watching." A durable version likely needs either an OS-level scheduled task invoking headless `claude -p "/loop"`, or leaning on `SessionStart`/`SessionEnd` hooks to track elapsed time/turns since the last `/learn` run and auto-trigger it at the start of each new session (which happens naturally and often, unlike a background daemon).

**Open question.** How much of this should live inside the harness itself (portable, stack-agnostic, works the moment `/forge` installs it) versus relying on an OS-level cron entry the user sets up once during install?

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

## R10 — "Live" awareness of the model's full toolset (open research question)

**Problem, in the maintainer's own framing:** the model isn't reliably aware of everything available to it — skills, MCP tools, harness mechanisms — so it under-uses its own capability. Flagged explicitly as unsolved, not a spec'd feature: *"I don't know how we'll do this, but we need to brainstorm it."*

**Status.** Genuinely open. Likely connects to R4's `loop-engineering-main` research (its "Loop Ready" scoring and five-building-blocks framing may address exactly this) and to how session-start context/`CLAUDE.md` pointers degrade in effectiveness once context compaction pushes them out of the active window.

**Proposed next step.** A dedicated brainstorming/research pass once R4 is done, rather than jumping straight to an implementation none of us have validated yet.

---

## R11 — Rate-limit-aware graceful pause and resume

**Problem.** Wants live session/weekly usage-remaining data fed to Claude so it can proactively wrap up before hitting a hard cutoff — pausing gracefully and saving exact state for a clean resume, instead of a response cutting off mid-work.

**Why it matters (maintainer's own reasoning).** Two benefits: work doesn't break mid-edit because the model ran out of room to finish, and the available budget gets used efficiently instead of wasted by finishing too early out of caution.

**Proposed approach.** Needs research into whether Claude Code exposes remaining session/weekly usage to a hook or the statusline today. If so, wire it into `session-start.sh` and/or the statusline, and add a rule instructing the model to checkpoint (commit, update `TASKS.md` status, note the exact next step) once usage crosses a threshold — rather than continuing until forcibly cut off.

---

## Contributing

Pick a section above, comment on (or open) the corresponding issue to claim it, and scope your PR to that section alone — these are intentionally independent so review stays small and focused. If a section's "open question" isn't resolved yet, raise it before writing code; several of these have a real fork in approach that changes the implementation significantly.
