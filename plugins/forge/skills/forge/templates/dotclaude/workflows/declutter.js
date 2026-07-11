export const meta = {
  name: 'declutter',
  description: 'Discover dead-code/orphan/duplicate candidates, then verify each one empirically in a single parallel fan-out — no separate verify phase, no trusting names or comments.',
  phases: [
    { title: 'Discover', detail: 'dead-code/dep tooling output + a naming/duplicate-pattern sweep, candidates only, no verification yet' },
    { title: 'Investigate', detail: 'one Explore agent per candidate — lists it, greps the whole repo for references, verifies empirically, returns a verdict' },
  ],
}

const CANDIDATE_SCHEMA = {
  type: 'object',
  required: ['candidates'],
  properties: {
    candidates: {
      type: 'array',
      items: {
        type: 'object',
        required: ['label', 'path', 'kind', 'whySuspect'],
        properties: {
          label: { type: 'string' },
          path: { type: 'string' },
          kind: { type: 'string', enum: ['dead-symbol', 'unused-dep', 'orphan-file', 'duplicate-pair', 'suspicious-name', 'commented-block'] },
          whySuspect: { type: 'string' },
        },
      },
    },
  },
}

const VERDICT_SCHEMA = {
  type: 'object',
  required: ['verdict', 'evidence', 'recommendation'],
  properties: {
    verdict: { type: 'string', enum: ['confirmed-dead', 'trap', 'promote-candidate', 'needs-your-call'] },
    evidence: { type: 'string' },
    recommendation: { type: 'string' },
  },
}

const discovery = await agent(
  `Scan this repository for decluttering candidates. Read .claude/harness.env for the project's build/lint commands and stack.
Run whatever dead-code/unused-dependency tooling actually applies to this stack (examples only — use what's real here: compiler dead-code warnings, cargo-machete/cargo +nightly udeps, knip/ts-prune/depcheck, ruff --select F401,F811/vulture/deptry, staticcheck/deadcode) and capture the raw output.
Also sweep with grep/glob for: files or directories named in a way that suggests staleness (archived, legacy, deprecated, old, backup, _copy, .bak, unused, duplicate, v1/v2 leftovers); pairs of directories/files with identical or near-identical names in different locations (possible duplicate implementations); large blocks of commented-out code (not doc comments).
This phase is discovery ONLY — do not verify anything yet, cast a wide net, false positives here are fine (they get verified next, one at a time). For each candidate return: a short label, the exact path, a kind classification, and one sentence on why it looks suspect.
Read-only. Do not edit, write, or delete anything.`,
  { phase: 'Discover', schema: CANDIDATE_SCHEMA }
)

const candidates = discovery?.candidates ?? []
if (!candidates.length) {
  log('No decluttering candidates found — nothing to investigate.')
  return { candidates: [], verdicts: [], buckets: { confirmedDead: [], traps: [], promoteCandidates: [], needsYourCall: [] } }
}
log(`${candidates.length} candidate(s) found — investigating each in its own parallel Explore agent`)

const verdicts = await parallel(
  candidates.map((c) => () =>
    agent(
      `Investigate this single decluttering candidate — verify EMPIRICALLY, do not trust its name, a comment, or the discovery step's guess.
Candidate: "${c.label}" at ${c.path} (suspected kind: ${c.kind}). Why it was flagged: ${c.whySuspect}

Do this:
1. List the actual contents/definition at that path.
2. Grep the ENTIRE repository (not just the local directory) for every reference/import/call site — quote exact file:line matches, or state plainly you found none.
3. If this looks like a duplicate/near-duplicate of something elsewhere, diff the two and classify: byte-identical, near-identical-with-drift, or substantially diverged — and determine which copy (if either) is actually live via import-path evidence.
4. If a comment or filename claims "archived"/"unused"/"deprecated", verify that claim against real wiring (is it still registered/imported/called anywhere?) rather than trusting the label — labels lie; a file can say ARCHIVED and still be live.
5. Before calling anything dead, rule out guard-zone exceptions: exported/public API, feature-flag/cfg-gated code, test fixtures, docs/CI-only references, or a manual ops/one-off script (zero automatic callers is normal for these, not a sign of death).

Return exactly one verdict: "confirmed-dead" (zero references anywhere, evidence-backed, safe to remove), "trap" (looked dead but a guard-zone exception or a hidden reference makes it still needed — removing it would break something), "promote-candidate" (not dead, but a genuine duplicate/consolidation opportunity — one copy should absorb the other), or "needs-your-call" (evidence is genuinely ambiguous or conflicting — a human must decide). Include the concrete evidence (quote the grep/diff output) and a one-line recommendation.
Read-only. Do not edit, write, or delete anything.`,
      { label: `investigate:${c.label}`, phase: 'Investigate', agentType: 'Explore', schema: VERDICT_SCHEMA }
    ).then((v) => (v ? { ...c, ...v } : null))
  )
)

const settled = verdicts.filter(Boolean)
const dropped = candidates.length - settled.length
if (dropped > 0) log(`${dropped} candidate(s) had no result (agent error/skip) — excluded from buckets, not silently counted as cleared`)

const buckets = {
  confirmedDead: settled.filter((v) => v.verdict === 'confirmed-dead'),
  traps: settled.filter((v) => v.verdict === 'trap'),
  promoteCandidates: settled.filter((v) => v.verdict === 'promote-candidate'),
  needsYourCall: settled.filter((v) => v.verdict === 'needs-your-call'),
}

log(`${buckets.confirmedDead.length} confirmed-dead, ${buckets.traps.length} trap(s) avoided, ${buckets.promoteCandidates.length} promote-candidate(s), ${buckets.needsYourCall.length} need your call`)

return { candidates, verdicts: settled, buckets }
