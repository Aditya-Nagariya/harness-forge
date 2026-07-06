export const meta = {
  name: 'elevate',
  description: 'Run a list of narrow implementation steps through the small-model cascade: small-executor attempts, a 3-aspect haiku verifier panel checks, one Reflexion-style retry with verifier evidence injected, then escalation to the session model. Steps run sequentially (same working tree).',
  phases: [
    { title: 'Execute', detail: 'haiku attempt (retry once with critique), escalate on second failure', model: 'haiku' },
    { title: 'Verify', detail: 'panel: build-and-tests, safety-and-conventions, diff-matches-intent', model: 'haiku' },
  ],
}

// args: array of step strings. Each must be ONE narrow, single-responsibility step
// with an explicit done-condition, e.g.:
//   ["Add a failing unit test in src/<module> asserting that
//     a registry entry missing `schema_version` fails validation naming the field.
//     Done when: the test command shows the new test failing with the expected message."]
//
// Design notes (evidence-backed, see .claude/memory/research/ digests):
// - Steps run SEQUENTIALLY: they share one working tree; parallelism belongs at the
//   task level (implement-tasks.js, worktree-isolated), not the step level.
// - Retry is bounded at 1 haiku retry (Reflexion gains come from the injected
//   evidence, not from more retries), then escalates to the session model —
//   escalate-after-<=2-attempts is the published cost-optimal cascade point.
// - Verifier evidence, not model self-judgment, drives every retry.

const VERIFY_ASPECTS = ['build-and-tests', 'safety-and-conventions', 'diff-matches-intent']

const steps = args
if (!Array.isArray(steps) || steps.length === 0) {
  throw new Error('Pass an array of narrow step strings, each with an explicit done-condition.')
}

function verifierPrompt(aspect, step) {
  return `ASPECT: ${aspect}\n\nThe step just attempted was:\n${step}\n\nInspect the current working tree (git diff HEAD for changes). Run your aspect's checklist and emit your exact output contract.`
}

async function verifyPanel(step, label) {
  const verdicts = await parallel(
    VERIFY_ASPECTS.map((aspect) => () =>
      agent(verifierPrompt(aspect, step), {
        label: `verify:${label}:${aspect}`,
        phase: 'Verify',
        agentType: 'small-verifier',
      })
    )
  )
  const failures = []
  verdicts.forEach((v, i) => {
    const text = String(v || '')
    if (!/VERDICT:\s*pass/i.test(text)) {
      failures.push(`[${VERIFY_ASPECTS[i]}]\n${text.slice(0, 1500)}`)
    }
  })
  return failures
}

const results = []
const routing = []

for (let i = 0; i < steps.length; i++) {
  const step = steps[i]
  const label = `step${i + 1}`
  let tier = 'haiku'
  let attempts = 0

  log(`${label}/${steps.length}: dispatching to small-executor`)
  attempts++
  let report = await agent(step, { label: `exec:${label}:haiku-1`, phase: 'Execute', agentType: 'small-executor' })
  let failures = await verifyPanel(step, `${label}-a1`)

  if (failures.length > 0) {
    log(`${label}: ${failures.length} verifier failure(s) — one haiku retry with evidence injected`)
    attempts++
    report = await agent(
      `${step}\n\n----- PRIOR ATTEMPT FAILED VERIFICATION (fix these specific findings; evidence below is from independent verifiers) -----\n${failures.join('\n\n')}`,
      { label: `exec:${label}:haiku-2`, phase: 'Execute', agentType: 'small-executor' }
    )
    failures = await verifyPanel(step, `${label}-a2`)
  }

  if (failures.length > 0) {
    log(`${label}: haiku failed twice — escalating to the session model`)
    tier = 'escalated'
    attempts++
    report = await agent(
      `${step}\n\n----- TWO SMALL-MODEL ATTEMPTS FAILED VERIFICATION. Latest verifier evidence: -----\n${failures.join('\n\n')}\n\nTake over this step: diagnose the actual root cause from the evidence, fix it properly, and verify with real command output.`,
      { label: `exec:${label}:escalated`, phase: 'Execute', agentType: 'small-executor', model: 'inherit' }
    )
    failures = await verifyPanel(step, `${label}-a3`)
  }

  const ok = failures.length === 0
  results.push({ step, ok, tier, attempts, report: String(report || '').slice(0, 2000), openFailures: failures })
  routing.push({ step: step.slice(0, 120), tier, attempts, ok })

  if (!ok) {
    log(`${label}: still failing after escalation — stopping the sequence (later steps likely depend on this one)`)
    break
  }
}

const done = results.filter((r) => r.ok).length
log(`${done}/${steps.length} steps verified. Routing outcomes returned in result.routing — append them to .claude/state/routing-stats.json (steps that chronically escalate should be dispatched to the stronger model directly next time).`)

return { results, routing }
