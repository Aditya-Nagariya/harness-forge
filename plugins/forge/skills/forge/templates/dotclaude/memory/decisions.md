# Decisions

Architecture/process decisions and *why* — not what (that's `activity-log.md`), not a Claude-behavior correction (that's `lessons/`). Format: `**[YYYY-MM-DD] — decision — why:** rationale.`

---

**[{{DATE}}] — Harness installed via /forge — why:** this project adopted the self-improving harness pattern (self-healing failure ledger, per-file lessons with promotion lifecycle, regression evals, small-model elevation agents). Evidence base for the design: `.claude/memory/research/`. Do not "simplify" a mechanism away without reading its evidence digest first.
