# Git workflow

## Branch naming

`feature/{name}` · `fix/{name}` · `refactor/{name}` · `chore/{name}`. Reference a `TASKS.md` ID in the branch/commit body where useful.

## Commit messages

Conventional Commits: `{type}({scope}): {description}`, types `feat|fix|refactor|docs|test|chore`.

## Safety (hook-enforced, restated)

No force-push (`--force-with-lease` + user OK if truly needed); no direct push to protected branches; no `git reset --hard`/`git clean -f` without confirmation; commits touching >20 files deserve a second look.

## Worktrees

For parallel/risky work where one line of work shouldn't destabilize another: `claude --worktree <name>` or the `EnterWorktree` tool instead of stashing; code-writing subagents can carry `isolation: worktree`. Full guidance in `.claude/GUIDE.md`.
