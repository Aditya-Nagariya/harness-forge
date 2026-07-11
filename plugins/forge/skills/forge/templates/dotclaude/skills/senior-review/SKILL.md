---
name: senior-review
description: "Holistic, single-pass senior-engineer review of the target project's actual code (not the harness) across security, performance, code quality, and production-readiness. Use for 'is this ready to ship', a full code review, a security audit, or a performance pass."
---

This is a **read-only, single holistic pass** over real project code — distinct from `/harness-audit` (which only audits `.claude/` itself) and from the gated multi-agent reviewer pipeline (`code-reviewer`/`security-reviewer`/`silent-failure-hunter` agents, `review-diff.js`), which this complements rather than replaces.

## Before reviewing

Build a mental model of the system before judging any line of it: read `CLAUDE.md` and `.claude/harness.env` for the stack, build/test/lint commands, and any documented exclusions (e.g. "no browser frontend here" makes XSS checks N/A) — don't duplicate that orientation into a separate file, it already has one source of truth.

## Phased checklist

Read the matching reference file **when you reach that phase** — don't hold all four checklists in your head at once, that's exactly the token cost `references/` avoids:

1. Security → `references/security.md`
2. Performance → `references/performance.md`
3. Code quality & maintainability → `references/code-quality.md`
4. Production readiness → `references/production-readiness.md`

Severity scale for every finding: see `references/severity.md` — the same scale every reviewer in this harness cites, so verdicts stay consistent across tools.

## Finding template (every finding, no exceptions)

```
Where:      file:line
What:       the issue
Impact:     concrete consequence — quantify it if you can ("at 1M rows this times out," not "this could be slow")
Fix:        the specific change (a snippet if non-trivial)
Confidence: 0-100
```

## Report shape (fixed, four sections in order)

1. **Critical Vulnerabilities & Security Flaws**
2. **Performance Optimizations**
3. **Code Quality & Maintainability**
4. **Pre-Deployment Checklist** (render `references/production-readiness.md`'s checklist as `[ ]`/`[x]` rows)

## Principles

- **Signal over volume.** A report with 40 nitpicks and 2 real blockers buries the blockers. Lead with what matters.
- **Evidence, always.** A grep hit is a lead, not a finding — confirm it's actually reachable/exploitable before reporting it as one.
- **Fix, don't just flag.** Every finding gets a concrete fix, not just a description of the problem.
- **Confirm reachability.** Before calling something a vulnerability, trace whether untrusted input can actually reach it.

Do not modify any files. Report findings only.
