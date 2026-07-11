export const meta = {
  name: 'implement-tasks',
  description: 'Implement multiple independent, pending TASKS.md items in parallel, each isolated in its own git worktree, then review each with three specialist lenses before reporting.',
  phases: [
    { title: 'Implement', detail: 'one worktree-isolated agent per task id, following the /milestone-task TDD flow' },
    { title: 'Review', detail: 'code-reviewer + security-reviewer + silent-failure-hunter per completed task, reading the diff via git rather than entering the worktree' },
  ],
}

// args: an array of independent, pending TASKS.md task IDs to implement in parallel,
// e.g. ["#001", "#003", "#009"]. Pick IDs that don't touch overlapping files — the
// point of worktree isolation is to avoid merge pain, not eliminate it.

const IMPLEMENT_SCHEMA = {
  type: 'object',
  required: ['taskId', 'branch', 'summary', 'verification'],
  properties: {
    taskId: { type: 'string' },
    branch: { type: 'string', description: 'git branch this work landed on (from `git branch --show-current` inside the worktree)' },
    filesChanged: { type: 'array', items: { type: 'string' } },
    summary: { type: 'string' },
    verification: { type: 'string', description: 'exact commands run to verify, per .claude/rules/ship-verification.md' },
  },
}

const REVIEW_SCHEMA = {
  type: 'object',
  required: ['blockers', 'consider'],
  properties: {
    blockers: { type: 'array', items: { type: 'string' } },
    consider: { type: 'array', items: { type: 'string' } },
  },
}

const taskIds = args

if (!Array.isArray(taskIds) || taskIds.length === 0) {
  throw new Error('Pass an array of TASKS.md task IDs to implement in parallel, e.g. ["#001", "#003"]')
}

log(`Implementing ${taskIds.length} task(s) in parallel, each in its own worktree: ${taskIds.join(', ')}`)

const results = await pipeline(
  taskIds,
  (taskId) => agent(
    `Read .claude/tasks/TASKS.md for task ${taskId} in this project. Follow the /milestone-task skill's red-green-refactor process to implement it fully: write a failing test, make it pass, refactor, run the build/test/lint commands from .claude/harness.env, and update TASKS.md/status.json/ARCHIVE.md per .claude/rules/ship-verification.md once genuinely verified end-to-end (not just built). Commit your work on the current branch, then run 'git branch --show-current' and report that branch name.`,
    { label: `implement:${taskId}`, phase: 'Implement', isolation: 'worktree', schema: IMPLEMENT_SCHEMA }
  ),
  (impl, taskId) => {
    if (!impl) return { taskId, impl: null, reviews: null }
    const diffHint = `From the current checkout, run 'git fetch --all 2>/dev/null; git diff main...${impl.branch}' (substitute the repo's actual default branch if not main) to see the real change — do not assume file contents, read the actual diff.`
    return parallel([
      () => agent(`${diffHint}\n\nReview this diff (task ${taskId}) for correctness and house-rule compliance.`, { label: `review:${taskId}:code`, phase: 'Review', agentType: 'code-reviewer', schema: REVIEW_SCHEMA }),
      () => agent(`${diffHint}\n\nReview this diff (task ${taskId}) for security issues.`, { label: `review:${taskId}:security`, phase: 'Review', agentType: 'security-reviewer', schema: REVIEW_SCHEMA }),
      () => agent(`${diffHint}\n\nHunt for silent-failure patterns in this diff (task ${taskId}).`, { label: `review:${taskId}:silent-failure`, phase: 'Review', agentType: 'silent-failure-hunter', schema: REVIEW_SCHEMA }),
    ]).then((reviews) => ({ taskId, impl, reviews: reviews.filter(Boolean) }))
  }
)

const finished = results.filter(Boolean)
const blockersFound = finished.flatMap((r) => (r.reviews || []).flatMap((rv) => rv.blockers || []))
log(`${finished.length}/${taskIds.length} tasks implemented; ${blockersFound.length} blocker(s) raised across reviews — read the per-task review output before merging any of these branches.`)

return results
