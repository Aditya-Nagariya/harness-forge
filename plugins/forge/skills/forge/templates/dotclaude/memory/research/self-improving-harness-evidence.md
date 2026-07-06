# Evidence base for this harness's self-healing/learning/elevation design

Digest of a 2026-07-05 research pass over the 2023–2026 literature. Each design rule below is load-bearing in this harness — don't "simplify" one away without reading its evidence.

## Rules this harness implements, with their evidence

1. **External deterministic feedback is the only correction signal.** Intrinsic self-correction (no external signal) fails and often degrades accuracy (Huang et al., ICLR 2024, arXiv:2310.01798; Stechly et al., arXiv:2402.08115). Reflexion's gains (HumanEval 91% vs 80%; arXiv:2303.11366) came from evaluator-grounded reflections (unit tests), and ablations show the *stored lesson*, not the retry, drives improvement. → Implemented as: `capture-failure.sh` (ledger from real tool errors), verifier panels that must cite command output, `/learn` refusing lessons without verbatim evidence.

2. **Delta-only memory updates; a script merges, an LLM never rewrites the store.** ACE (arXiv:2510.04618) documents "context collapse": one full LLM rewrite crushed an 18k-token playbook to 122 tokens with below-baseline accuracy. Their fix — itemized bullets with IDs and helpful/harmful counters, deterministic merge — is our lesson-file + INDEX-line delta policy.

3. **Lesson lifecycle with vote counters.** ExpeL (arXiv:2308.10144): ADD/EDIT/UPVOTE/DOWNVOTE with importance counters, delete at 0. ReasoningBank (arXiv:2509.25140): atomic items (title + one-liner + 1–3 sentences), retrieval k≈1, memory from failures AND successes: up to +34.2% relative on agent benchmarks. → Our per-file lessons with `weight`, top-3 session-start injection, `/learn`'s retrieve-before-write policy.

4. **Mechanizable rules terminate as hooks, not prose.** Practitioner consensus: ~70–90% compliance for prompt rules vs ~100% for hooks. IFScale (arXiv:2507.11538): instruction-following decays with rule count (best models 68% at 500 rules; small models degrade fastest). → `/learn`'s promotion rule: weight ≥3.0 + mechanically checkable ⇒ hook or regression check, not a CLAUDE.md line.

5. **Small-model elevation = decomposition + layered verification + bounded escalation.** Verified best-of-N took SWE-bench Lite 15.9%→56% but *only with an automatic verifier* (arXiv:2407.21787). Weak generator + strong verification approaches strong-generator quality (arXiv:2509.17995); panels of narrow single-aspect verifiers ≈ one strong verifier (arXiv:2502.20379). Small models can't usefully free-form self-critique (ACL 2024 Findings). Decomposition into narrow steps disproportionately helps small models (least-to-most, arXiv:2205.10625: SCAN 16%→99.7%). Schema-constrained generation hurts reasoning ~10–15% — reason in prose, then format (arXiv:2408.02442). Cascades: ~95% of frontier quality at 85–98% cost reduction, escalating ~14% of queries (FrugalGPT arXiv:2305.05176, RouteLLM). Escalate after ≤2 attempts; if the first small-model draft isn't even plausible, skip retries entirely (Snell, arXiv:2408.03314). → `haiku-executor` (narrow contract, prose-then-report), `haiku-verifier` (single-aspect checklists), `elevate.js` (1 retry with injected evidence, then escalate, routing outcomes logged).

6. **Scaffold beats model upgrades.** Same-model scaffold changes moved SWE-bench 42%→78% (particula.tech analysis); GEPA (arXiv:2507.19457): reflective prompt evolution beats RL fine-tuning with 35× fewer rollouts. → The harness itself is the highest-leverage artifact; `/harness-audit` + regression evals treat it as versioned, tested software.

7. **Every confirmed failure becomes a permanent regression check.** Production observability loop (trace→cluster→eval→fix). → `.claude/evals/regressions/` seeded with checks 0001–0003, run by `/harness-audit` and CI.

## Boundaries to respect

- Retrieval/lesson overhead can exceed value on trivial tasks (arXiv:2606.15017) — hence k≤3 injection, not the full store.
- Unmanaged lifelong accumulation degrades capability (arXiv:2605.09315) — hence weight decay/retirement, ~150-line agent-memory curation guidance.
- The hardest problems still need the big model (Snell) — the cascade escalates; it does not insist.
