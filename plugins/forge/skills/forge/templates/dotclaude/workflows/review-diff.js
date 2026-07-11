export const meta = {
  name: 'review-diff',
  description: 'Review the current uncommitted git diff across three lenses (correctness, security, silent-failure), then adversarially verify each blocker (3 independent refuters, majority-survives) before reporting.',
  phases: [
    { title: 'Review' },
    { title: 'Verify' },
  ],
}

const LENSES = [
  { key: 'correctness', agentType: 'code-reviewer', prompt: "Run 'git diff' and 'git diff --cached' to see the current uncommitted changes in this checkout. Review for correctness and house-rule compliance." },
  { key: 'security', agentType: 'security-reviewer', prompt: "Run 'git diff' and 'git diff --cached' to see the current uncommitted changes in this checkout. Review for security issues." },
  { key: 'silent-failure', agentType: 'silent-failure-hunter', prompt: "Run 'git diff' and 'git diff --cached' to see the current uncommitted changes in this checkout. Hunt for silent-failure patterns." },
]

const REVIEW_SCHEMA = {
  type: 'object',
  required: ['blockers', 'consider'],
  properties: {
    blockers: {
      type: 'array',
      items: {
        type: 'object',
        required: ['finding'],
        properties: { finding: { type: 'string' }, file: { type: 'string' } },
      },
    },
    consider: { type: 'array', items: { type: 'string' } },
  },
}

const VERDICT_SCHEMA = {
  type: 'object',
  required: ['refuted'],
  properties: { refuted: { type: 'boolean' }, reason: { type: 'string' } },
}

const reviews = await parallel(
  LENSES.map((l) => () => agent(l.prompt, { label: `review:${l.key}`, phase: 'Review', agentType: l.agentType, schema: REVIEW_SCHEMA }))
)

const allBlockers = reviews
  .filter(Boolean)
  .flatMap((r, i) => (r.blockers || []).map((b) => ({ ...b, lens: LENSES[i].key })))

log(`${allBlockers.length} raw blocker(s) raised across ${LENSES.length} lenses — verifying adversarially`)

const verified = await pipeline(
  allBlockers,
  (b) =>
    parallel(
      Array.from({ length: 3 }, () => () =>
        agent(
          `Try to REFUTE this code review finding (default to refuted=true if uncertain): [${b.lens}] ${b.finding}${b.file ? ' (' + b.file + ')' : ''}. Read the actual code before judging — don't take the finding's word for it.`,
          { phase: 'Verify', schema: VERDICT_SCHEMA }
        )
      )
    ),
  (votes, b) => ({ ...b, survives: votes.filter(Boolean).filter((v) => !v.refuted).length >= 2 })
)

const confirmed = verified.filter(Boolean).filter((v) => v.survives)
log(`${confirmed.length} of ${allBlockers.length} raw blockers survived adversarial verification`)

return {
  confirmed,
  allRaised: allBlockers,
  considerNotes: reviews.filter(Boolean).flatMap((r) => r.consider || []),
}
