# Claude Code native features this harness relies on

Digest of a 2026-07-05 documentation pass (code.claude.com/docs: sub-agents, hooks, scheduled-tasks, memory, skills, model-config). Version floors noted where the docs state them.

- **Agent persistent memory**: `memory: user|project|local` frontmatter. `project` → `.claude/agent-memory/<agent-name>/`, committed/shareable. First 200 lines or 25KB of `MEMORY.md` injected into the agent's system prompt with curation instructions; Read/Write/Edit auto-enabled for the memory dir. Used by: `haiku-executor`, `rust-code-reviewer`.
- **PostToolUseFailure hook event**: input carries `tool_name`, `tool_input`, **`tool_error`** (that's the field name), `tool_use_id`. Used by: `capture-failure.sh`.
- **Prompt-type hooks** (`type: prompt`): single-turn LLM evaluation of the hook decision, `$ARGUMENTS` = hook input JSON, defaults to a fast model. On Stop/SubagentStop it emits `{"decision":"block","reason":...}` to force continued work. Agent-frontmatter `Stop` hooks auto-convert to SubagentStop. Used by: `haiku-executor`'s completion gate.
- **`.claude/loop.md`**: replaces the built-in bare-`/loop` maintenance prompt; plain markdown, 25KB cap, edits take effect next iteration. Ours routes: in-flight work → `/learn` on hot signatures → `/harness-audit` → next pending task.
- **Maintenance mode**: `claude -p --maintenance "<prompt>"` fires `Setup` hooks with `matcher: maintenance` — the sanctioned path for a cron-driven nightly audit (in-session `/loop` has a 7-day expiry and needs the session open).
- **Explore override**: a project agent named `Explore` overrides the built-in; docs explicitly recommend `model: haiku` to pin exploration to a cheap model. Ours: `.claude/agents/Explore.md`.
- **Model/effort routing**: per-agent `model:`/`effort:` frontmatter; per-invocation Agent-tool `model` param beats frontmatter (resolution: `CLAUDE_CODE_SUBAGENT_MODEL` env → invocation param → frontmatter → inherit). `maxTurns` caps agentic turns. Used by: executor/verifier agents, `elevate.js` escalation.
- **Path-scoped rules**: `paths:` frontmatter (glob list) on `.claude/rules/*.md` — loads only when Claude reads matching files; `InstructionsLoaded` hook event (`load_reason: path_glob_match`) can audit whether they ever fire. Not yet used here (rules are small); adopt if the rules grow.
- **`TaskCompleted` hook**: exit 2 blocks a task from being marked complete — candidate future home for the ship-verification gate as enforcement rather than convention.
- **`.worktreeinclude`**: gitignore-syntax file listing gitignored files to copy into new worktrees (ours copies `CLAUDE.local.md`).
