# Harness Improvement Study

A detailed research study of what to improve next, from (a) a gap analysis re-mining the three example harnesses under `example harness/` for mechanisms we did **not** adopt, and (b) an adversarial audit of our two repos (`cliorch/.claude`, `harness-forge/`). Every claim below is grounded in a tool result from this session; where a number appears, it was measured, not estimated from memory.

Status legend: **[verified]** = confirmed by a command this session · **[from-audit]** = reported by the adversarial audit agent · **[from-gap]** = reported by the gap-mining agent.

---

## Part A — The single most important finding (verified)

**Our always-loaded context is ~5× over the evidence-based budget, and we blew a budget we ourselves documented.**

Measured this session (chars/4 heuristic, path-scoped rules excluded):

| File | tokens | lines |
|---|---|---|
| `cliorch/CLAUDE.md` | 4,220 | 92 |
| `rules/git-workflow.md` | 861 | 29 |
| `rules/safety.md` | 354 | 9 |
| `rules/rust-style.md` | 334 | 7 |
| `rules/ship-verification.md` | 285 | 8 |
| **always-loaded total** | **≈ 6,054** | — |

The research digest we shipped (`memory/research/self-improving-harness-evidence.md`) and our own `GUIDE.md` §6 both state the target is <1,200 tokens / 1,500 hard cap, because instruction-following decays as rule count grows and small models degrade fastest (IFScale, arXiv:2507.11538). We are at ~6,054. This is the highest-value fix and it is self-inflicted: `CLAUDE.md` grew to 92 lines documenting every subsystem, when most of that belongs in on-demand skill/guide content, not always-loaded context.

**Fix:** cut `CLAUDE.md` to a ~25-line index (project one-liner, commands, pointers to GUIDE/skills/rules), move the subsystem prose into the skills/GUIDE that already exist, and make several always-loaded rules path-scoped (`rust-style.md` → `paths: ["**/*.rs"]`, `git-workflow.md` is only relevant on git operations). Then add the regulator so this can't silently recur (Part B, item 2).

---

## Part B — Gaps worth adopting (from gap analysis, ranked)

### Tier 1 — high value

1. **Output styles: `terse` + `reality-check`.** [from-gap] Two `output-styles/*.md` toggled via `/output-style`, with `keep-coding-instructions: true` so they compose with our hooks. `terse` = smallest-artifact + one routing line (per-session token saver); `reality-check` = anti-sycophancy Principal-Engineer persona with a fixed `Verdict: SHIP/FIX FIRST/RETHINK/NEEDS DATA` → findings → Socratic-follow-ups output. We have **none** [verified: `.claude/output-styles/` absent]. **ADOPT** as forge templates — `reality-check` is exactly the mode `/harness-audit` and `/ship` review turns want.

2. **CI token-budget gate + `/context-budget` skill.** [from-gap] A CI job that sums always-loaded `chars/4`, skips `^paths:` files, and `exit 1` if `> 1200`; plus a skill that classifies every `.claude/` file into always-loaded / path-scoped / invoked-only and reports a PASS/NEAR/OVER verdict. We have neither [verified: no `context-budget` skill, no token-budget CI job]. **ADOPT** — this is the missing regulator for Part A; a self-improving harness that accretes lessons *will* bloat, and our config-drift fingerprint tracks change, not cost.

3. **Reviewer/agent house-contract CI grep-guard.** [from-gap] A CI job that greps each agent file for its required invariants (confidence threshold present, required section headers present) and fails on drift — the same primitive as our existing SEC-1 grep, applied to agent structure. **ADOPT**; near-zero cost, protects our `small-executor`/`small-verifier` contracts from silent erosion during self-edits.

4. **Earned-capability gate hooks (prove-you-consulted-X-before-editing).** [from-gap] A stateful gate: a PostToolUse hook `touch`es a flag when some prerequisite happens; a PreToolUse hook blocks the first source edit until the flag exists; SessionStart clears the flags so it's re-earned each session. **ADAPT** — drop the Gemini/Context7 specifics, keep the shape: block the first source edit of a session until the lessons INDEX / failure ledger was read (turns our *recommended* read-before-write into a *hook-enforced* invariant).

5. **Ship-verification: transport-vs-feature doctrine.** [from-gap] A green smoke test proving reachability is a *red* feature test; only asserting the semantic outcome (right value / right label), simulating the client's half of the protocol, and saving a committed re-runnable verify script counts as shipped. **ADOPT** into `/ship` and the regression-evals convention — closes the "tests passed but the feature never ran" gap our auto-test hook doesn't cover.

6. **PreCompact snapshot hook.** [from-gap] Fires on the compaction boundary specifically (which our Stop reminder and HANDOFF don't), appending a durable resume marker (branch, commit, dirty, active-task count) idempotently once/day. We have no PreCompact hook [verified]. **ADOPT** — cheap deterministic durability win.

7. **Harness-as-overlay dual-repo install mode.** [from-gap] A bare git repo outside the project tree tracking only `.claude/`+`CLAUDE.md`, with leak-guard hooks, so the harness is versioned and portable into repos you can't commit into (client repos, submodules). **ADAPT** as a second forge install mode alongside in-tree.

8. **`add-component` doc-sweep protocol.** [from-gap] A trigger-phrase rule ("I am adding X") that blocking-updates all index surfaces before code work, so a new component is never invisible to the next session. **ADOPT** — complements our session-start injection (injection *reads* the indexes; this *keeps them complete*).

### Tier 2 — medium value

9. **Severity-tiered lint SSOT (`lints.md`).** [from-gap, verified absent] One file of 🔴/🟠/🟡/🔵 rows consumed by every review surface with a machine-followable gate ("any 🔴/🟠 → block"). **ADAPT** — give `small-verifier` and `/ship` a shared severity source so verdicts are consistent and edited in one place.
10. **Debug-signature reminder (3 edits → capture).** [from-gap] PostToolUse counter that nudges to log an issues-solved entry when the same file is edited 3× in a session — a *different* trigger from our failure-ledger (which fires on test failure). **ADOPT**.
11. **Quantitative priority scoring for TASKS.md.** [from-gap] A composite score (base×2 + blocking + age + security − blocked) bucketed P0–P3, giving `/catchup` a deterministic "next task" instead of vibes. **ADAPT** (trim team/assignee weights).
12. **pr-review deconfliction + confidence buckets.** [from-gap] Domain-precedence rules when parallel reviewers disagree (security > code on input handling, etc.) + confidence buckets (90+ act, 80–89 "consider", <80 drop). **ADAPT** into `elevate.js`'s verifier-panel synthesis.
13. **≥80-confidence + "What NOT to flag" reviewer contract.** [from-gap] Cuts false-positive noise; clone the silent-failure-hunter as a dedicated verifier aspect. **ADOPT**.
14. **Schema-validated session-state + EndSession handoff discipline.** [from-gap] A `blocked[{reason}]` / `git.commitsThisSession` / move-inProgress→stashedWork ledger. **ADAPT** into HANDOFF.
15. **Documentation staleness thresholds + orphan audit.** [from-gap] Per-type staleness (lessons/issues/research) + orphan detection (no inbound reference) as a quantitative rubric for `/harness-audit`. **ADAPT**.

### Tier 3 — adopt if cheap
16. Canonical-vs-duplicated rule tension (main-thread rules DRY to one file; isolated-agent rules duplicate + grep-guard). **ADAPT per-consumer.**
17. `debug-fix --fast` emergency dual-mode. 18. `refactor --diff` scope guardrails (mostly covered by `/simplify`; SKIP-partial). 19. Statusline context-aware gate warnings (only if #4 adopted). 20. Correction-type-weighted promotion (explicit 1.0 / implicit 0.5 / mood 0.2 / self-induced 0.8) — a low-effort refinement of our flat lesson weights.

---

## Part C — Bugs & fragilities in our own build (adversarial audit)

_(folded in from the adversarial-audit agent below; my own independently-verified items are marked [verified].)_

**Verified by me this session, ahead of the audit:**

- **[verified] bootstrap.sh leaves orphan files on downgrade/rename.** The upgrade path records a sha256 manifest but never removes a file that a newer template version deleted or renamed — the old installed copy lingers forever. Fix: diff the new manifest's key set against the old one; for pristine orphans (hash matches old manifest), delete; for modified orphans, report.
- **[verified] No version-gated migration.** `forge_version` is recorded in the manifest but never *compared* — there's no path for "harness.env gained a required KEY" or "template file X was restructured." Fix: a `migrations/` map keyed by version with small idempotent steps, run when installed-version < plugin-version.
- **[verified — false alarm, keep as lesson] block-dangerous regex is sound.** An earlier probe showed `rm -rf "crates"` returning exit 0; clean re-testing via a JSON file showed it correctly exits 2. The exit-0 was a **quoting artifact of my test harness** (nested double-quotes in `echo`), not a hook bug. Lesson: test the test — verify a probe's own fidelity before trusting a negative result. `git   push` (extra spaces), `git push -f`, `/bin/rm`, `&&`-chained, and env-prefixed dangerous commands were all confirmed blocked.
- **[verified] Malformed-JSON to protect-files fails open.** `protect-files.sh` advertises fail-*closed*, but bad JSON (not just missing python3) yields empty `FILE_PATH` → exit 0 (allow). Low severity (no path = nothing to protect), but the stated guarantee is inaccurate. Fix: distinguish "unparseable input" (fail closed) from "parsed, no file_path" (allow).

**From the adversarial audit agent — all HIGH/most MEDIUM reproduced by me and FIXED this session:**

| ID | Finding | Status | Evidence |
|---|---|---|---|
| **H1** | `rm -fr`, `rm -r -f`, `rm -Rf`, `rm -fr crates/` all leak (exit 0) — flag-order/split/case defeat the regex | **[verified → FIXED]** | reproduced (all exit 0); rewrote both hooks with a `shlex` tokenizer; 32 fixtures pass incl. all leaking spellings now blocked |
| **H2** | `git -c … push --force` and `git --no-pager push --force` bypass every git guard (adjacency assumption) | **[verified → FIXED]** | reproduced (exit 0); tokenizer now skips global options to find the real subcommand |
| **H3** | "`PostToolUseFailure` isn't a real event → self-healing loop inert" | **[REFUTED]** | this session's own hooks-doc fetch lists `PostToolUseFailure` with a `tool_error` field, and the earlier live headless run captured a real EISDIR failure to the ledger unprompted. The loop works; agent worked from an incomplete event list. |
| **H4** | Statusline + session-start emit `0\n0` garbage on zero tasks (`grep -c \|\| echo 0`) | **[verified → FIXED]** | reproduced (3 broken lines); fixed in all 4 files; statusline now one clean line. Lesson 0007. |
| **M1** | forge `status.schema.json` never genericized (requires `clippy`/`fmt` no generic hook writes) — seed fails its own schema | **[verified → FIXED]** | schema now `build/lint/tests`; seed validates (missing-required: none) |
| **M5** | Upgrade leaves orphaned files when a template is deleted/renamed; `forge_version` never compared | **[verified → FIXED]** | added orphan-pruning (delete pristine, warn on modified); tested — injected orphan removed on re-upgrade |
| **M7** | session-start `set -euo pipefail`: one failed sub-block drops all context | **[FIXED]** | switched to `set -uo pipefail` (matches other hooks) in both repos |
| **M8** | `notify.sh` interpolates message into `osascript -e` string → AppleScript injection | **[FIXED]** | rewrote to pass message via `osascript` argv in both repos |
| **M10** | Substitution multi-pass: a `{{KEY}}` inside injected house-rules gets re-expanded / order-dependent | **[verified → FIXED]** | single-pass `re.sub`; literal `{{BUILD_CMD}}` in house rules now survives un-expanded (tested) |
| **L1** | forge regression checks cite "lesson 0005"/"0003" but forge ships lessons 0001/0002 | **[verified → FIXED]** | renumbered forge references (cliorch's were already correct) |
| **L7** | cliorch rules cite nonexistent `pre-tool-use.sh` | **[verified → FIXED]** | corrected to `sec1-guard.sh` / `block-dangerous-commands.sh` |

**Deferred (valid, lower priority — tracked, not yet done):** M2 (cliorch `fmt` health never written — drop from schema or have format-on-save record it), M3/M4 (harness-audit and /forge skill `allowed-tools` too narrow for the python checks / block-path proof they mandate — broaden the allowlists), M6 (new required `harness.env` keys invisible on upgrade — diff tmpl keys and append missing ones), M9 (SEC-1 guard misses `/bin/sh`, `bash`, `powershell` spawn forms — broaden + admit it's heuristic in docs), M11/L3 (validate.sh and bootstrap SETS quoting edge cases), L5 (successive upgrades clobber an unmerged `.forge-new` — version the suffix), L2 handled as a side effect of the H1/H2 rewrite (branch-substring false positive gone — `git push origin feature/main-refactor` now allowed, verified).

---

## Part D — Recommended execution order

1. **Cut CLAUDE.md + path-scope rules** (Part A) — biggest measured win, unblocks everything.
2. **Add the token-budget CI job + `/context-budget` skill** (B2) — locks in #1 permanently.
3. **Fix bootstrap orphan-pruning + add a migration map** (C) — the two real installer bugs, before anyone upgrades a real project.
4. **Ship `reality-check` + `terse` output styles** (B1) and the **agent-contract CI guard** (B3) — high value, low effort.
5. **Adopt the transport-vs-feature ship doctrine** (B5) and **PreCompact snapshot** (B6).
6. Then the Tier-2 items as the harness sees real use and the failure ledger tells us which matter.
