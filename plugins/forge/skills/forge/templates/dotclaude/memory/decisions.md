# Decisions

Architecture/process decisions and *why* — not what (that's `activity-log.md`), not a Claude-behavior correction (that's `lessons/`). Format: `**[YYYY-MM-DD] — decision — why:** rationale.`

---

**[{{DATE}}] — Harness installed via /forge — why:** this project adopted the self-improving harness pattern (self-healing failure ledger, per-file lessons with promotion lifecycle, regression evals, small-model elevation agents). Evidence base for the design: `.claude/memory/research/`. Do not "simplify" a mechanism away without reading its evidence digest first.

**[{{DATE}}] — R12 coding-discipline rides the `HOUSE_RULES` substitution, not a `rules/*.md` file — why:** the six isolated agents never see `rules/*.md`; `CLAUDE.md` is copy-only-if-absent, so a pointer added there never reaches an already-forged project; and an always-loaded rules file measured ~1448 of a 1500 hard cap once a project's real house rules are populated. `HOUSE_RULES` is the only channel that reaches all six agents *and* survives upgrades (`agents/` is harness-code zone). Kept out of `HOUSE_RULES_BULLETS` so `CLAUDE.md`'s budget stays untouched. Presence is CI-gated by `evals/regressions/0005-coding-discipline-reaches-every-agent.sh`. Deterministic diff-scope enforcement was deferred to R14 pending a machine-parseable `TASKS.md` `Files:` contract — don't "simplify" this into a rules file without re-reading those four reasons.
