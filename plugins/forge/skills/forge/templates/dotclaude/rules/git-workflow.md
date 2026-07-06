# Git workflow

## Branch naming

| Type | Pattern | Example |
|---|---|---|
| Feature | `feature/{name}` | `feature/registry-loader` |
| Fix | `fix/{name}` | `fix/session-timeout` |
| Refactor | `refactor/{name}` | `refactor/split-executor` |
| Chore | `chore/{name}` | `chore/bump-deps` |

Reference `TASKS.md` IDs in the branch name or commit body where useful: `feature/registry-loader-001`.

## Commit messages

Conventional Commits: `{type}({scope}): {description}`, types `feat|fix|refactor|docs|test|chore`.

## Worktree isolation for parallel/risky work

Use a **git worktree** instead of stashing/branch-switching when two lines of work would otherwise collide in the single working tree — an in-progress change on one shouldn't destabilize the other while both need to stay testable.

- `claude --worktree <name>` creates `.claude/worktrees/<name>/` on branch `worktree-<name>` (gitignored), or ask Claude mid-session to "work in a worktree" (`EnterWorktree` tool).
- Subagents that write code should carry `isolation: worktree` in their frontmatter so parallel edits never collide (temporary worktree, auto-cleaned if unchanged).
- `.worktreeinclude` at the repo root lists gitignored files (like `CLAUDE.local.md`) to copy into each new worktree.

## Safety (hook-enforced, restated)

No force-push (`--force-with-lease` + user confirmation if truly needed); no direct push to protected branches; no `git reset --hard`/`git clean -f` without user confirmation; commits touching >20 files deserve a second look before shipping.
