# Coding Discipline House Rules (R12) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship ROADMAP.md's R12 — "Think before coding" + "Surgical changes" — so it reaches every isolated code-writing/reviewing agent in this harness, costs zero always-loaded context budget, survives `/forge` upgrades into existing projects, and is mechanically verified against drift.

**Architecture:** One substitution, not six file edits. `{{HOUSE_RULES}}` is the only channel in this harness that is already injected into all six isolated agents (`small-executor`, `bug-fixer`, `code-reviewer`, `small-verifier`, `security-reviewer`, `silent-failure-hunter`) — each introduces it with the literal framing *"House rules (restated, since you can't see `.claude/rules/*.md`)"* — **and** propagates on upgrade, because `agents/` is harness-code zone (verified: absent from both `USER_DATA_PREFIXES` and `USER_DATA_FILES` in `bootstrap.sh:111-112`, so pristine agent files are rewritten with fresh substitutions). This plan prepends a fixed literal to `HOUSE_RULES` in `bootstrap.sh` while leaving `HOUSE_RULES_BULLETS` (which feeds the budget-charged `CLAUDE.md`) untouched, then adds a regression check so a future edit can't silently drop a surface.

**Tech Stack:** Python (the `bootstrap.sh` embedded substitution block), bash (one new `evals/regressions/` check), markdown (agent/skill prose).

## Why this replaces an earlier draft — read before executing

A previous version of this plan added an always-loaded `rules/coding-discipline.md` plus hand-edits to six files. Three independent verification agents reviewed it against the real repo and found it unshippable. Every finding below was **independently reproduced** before this rewrite; they are the reason the design changed, and re-introducing any of these approaches would re-introduce a confirmed defect:

- **The Stop-hook edit broke the harness's only working gate.** The old draft rewrote `small-executor.md`'s Stop-hook prompt so its two block conditions became conjunctive (`AND` instead of `or`) — meaning an agent reporting *no verification evidence at all* would pass, as long as it stated an assumption. Verified by direct string comparison. In `elevate.js` that gate is the only thing between a Haiku "done!" and the verifier panel. **Task 2 below fixes the gate's real gap without weakening it.**
- **Nothing landed on existing projects.** `CLAUDE.md` is in `bootstrap.sh`'s `root_map` (copy-only-if-absent, `bootstrap.sh:234-238`), so a pointer edit there never reaches an already-forged project — the new rules file would arrive as an orphan nothing references, which `/harness-audit` Phase 2 item 10 then proposes retiring as dead weight.
- **The budget claim was measured on an unrepresentative fixture.** The old draft measured 1337 tokens with `{{HOUSE_RULES_BULLETS}}` at its *unconfigured* placeholder value. With the 3–6 real house rules `/forge`'s own `SKILL.md:26` specifies, the real total is ~1448 against a 1500 hard cap — consuming 72% of a real project's headroom, with slightly longer rules turning CI red in projects that changed nothing. **This plan's design costs zero budget, so this class of failure is gone, not mitigated.**
- **The `git-workflow.md` trim was justified by a false "pure duplication" claim.** Verified: `no direct push to protected branches` appears **zero** times in `safety.md`, and `commits touching >20 files deserve a second look` appears exactly once in the entire template tree. The trim would delete unique content — and would itself violate the rule this plan ships ("don't remove pre-existing dead code unasked"). **No trim in this plan.**
- **The review-side check was structurally filtered out.** `workflows/review-diff.js` routes every `code-reviewer` blocker through three refuters prompted to *"default to refuted=true if uncertain"*, given only the finding string — no task description. "This change doesn't trace to the stated task" is unconfirmable from code alone, so scope-creep blockers would be refuted at near-100%. **Task 4 routes scope-creep to `consider`, which bypasses the refuter phase entirely.**

## Global Constraints

- Only "Think before coding" and "Surgical changes," in this harness's own voice. "Simplicity First" and "Goal-Driven Execution" stay out of scope (already covered by Claude Code's base prompt and by `rules/ship-verification.md` + `/milestone-task`'s TDD loop respectively — see ROADMAP.md's R12 entry).
- **Zero always-loaded context-budget change.** `context-budget.sh` measures only `CLAUDE.md` + non-`paths:`-scoped `.claude/rules/*.md` (verified by reading the script: it globs `["CLAUDE.md"] + glob.glob(".claude/rules/*.md")`, then excludes `README.md` and any rule whose frontmatter declares `paths:`). This plan adds no rules file and does not touch `CLAUDE.md`/`HOUSE_RULES_BULLETS`. Task 5 Step 4 verifies the total is unchanged from the pre-change baseline.
- **`HOUSE_RULES` and `HOUSE_RULES_BULLETS` must stay split.** They currently share one value (`bootstrap.sh:80-81`). `HOUSE_RULES` → the six agent files (not budget-charged). `HOUSE_RULES_BULLETS` → `CLAUDE.md` (budget-charged). Only the former gets the new content. Conflating them re-introduces the budget failure above.
- **Do not add the content to `agents/*.md` files by hand.** They already contain `{{HOUSE_RULES}}`; the substitution delivers it. Hand-editing would create the six-way drift problem this design exists to avoid.
- Before editing any file below, read it first and confirm it matches the quoted "before" text. Every quoted anchor in this plan was verified byte-for-byte against HEAD (including escaped-quote YAML and em-dashes) — if one doesn't match, the repo moved: stop and report NEEDS_CONTEXT rather than guessing.

## Scope boundary: what this plan does and does not enforce

Stated plainly because the user's requirement was "this feature should actually work," and overclaiming here would be the exact failure mode this harness's `rules/ship-verification.md` calls "rounding up":

- **Mechanically enforced by this plan:** that the content *reaches* every agent surface (Task 3's regression check — deterministic, CI-gated, fails red if a surface loses it).
- **Semi-enforced (LLM-judged):** assumption-surfacing on `small-executor`, via its existing `type: prompt` Stop hook (Task 2). This is a single-turn judgment on a fast model, not a deterministic gate — a real but weaker class than a bash `PreToolUse` hook. This plan does not claim otherwise.
- **Advisory only:** everything else. The model may not comply. Honest and unavoidable for "state your assumptions when intent is genuinely ambiguous" — whether intent *was* ambiguous is irreducibly a judgment call, so no hook can decide it.
- **Deliberately NOT attempted:** a deterministic "does every changed file trace to the task?" hook. It was considered and rejected on evidence: `tasks/TASKS.md`'s `Files:` field is freeform prose (the shipped template literally reads `Files: (expected files)`), so diffing `git diff --name-only` against it would produce false positives on any project that writes prose there — and a gate that cries wolf gets ignored or disabled, which is worse than no gate. Task 5 Step 3 files this as a new ROADMAP item (R14) with the prerequisite named (a machine-parseable `Files:` contract), rather than shipping an unreliable hook now.

---

### Task 1: Inject the coding-discipline literal into `{{HOUSE_RULES}}` via `bootstrap.sh`

**Files:**
- Modify: `plugins/forge/skills/forge/scripts/bootstrap.sh`

**Interfaces:**
- Produces: every installed `.claude/agents/*.md` file's "House rules (restated...)" section now opens with a `## Coding discipline` block, on both fresh install and upgrade. Task 3's regression check asserts exactly this.
- Consumes: nothing from earlier tasks.

- [ ] **Step 1: Read the current substitution block and confirm it matches**

Run: `sed -n '69,84p' plugins/forge/skills/forge/scripts/bootstrap.sh`

Confirm these five lines appear consecutively (this is inside the `python3 - <<'PY'` embedded block):
```python
house_rules = "(none configured — run /forge to fill project conventions)"
if house_rules_file and os.path.exists(house_rules_file):
    house_rules = open(house_rules_file, encoding="utf-8").read().strip()
subs["HOUSE_RULES"] = house_rules
subs["HOUSE_RULES_BULLETS"] = house_rules
```
If they don't match, STOP and report NEEDS_CONTEXT.

- [ ] **Step 2: Replace those five lines with the split-substitution version**

Replace the exact block from Step 1 with:

```python
house_rules = "(none configured — run /forge to fill project conventions)"
if house_rules_file and os.path.exists(house_rules_file):
    house_rules = open(house_rules_file, encoding="utf-8").read().strip()

# Coding discipline (ROADMAP R12) rides the HOUSE_RULES channel on purpose: it is the
# only substitution injected into all six isolated agents (small-executor, bug-fixer,
# code-reviewer, small-verifier, security-reviewer, silent-failure-hunter), each of which
# introduces it with "House rules (restated, since you can't see .claude/rules/*.md)" —
# and agents/ is harness-code zone, so an upgrade rewrites them with fresh substitutions.
# A rules/*.md file would reach none of them (isolated context) and would cost
# always-loaded context budget; CLAUDE.md is copy-only-if-absent so a pointer there never
# reaches an existing project. Kept OUT of HOUSE_RULES_BULLETS deliberately: that one
# feeds CLAUDE.md, which IS budget-charged by context-budget.sh.
# Presence on every agent surface is CI-gated by evals/regressions/0005-*.sh — if you
# edit the wording here, that check keeps the surfaces honest but not the phrasing.
CODING_DISCIPLINE = """## Coding discipline (applies to every change you make)

**Think before coding.** State non-obvious assumptions up front — don't silently pick one interpretation and run with it. When a request is genuinely ambiguous, name the readings, pick the sensible default, and flag it rather than guessing silently. Say so if a simpler approach exists than the one implied. When genuinely confused, stop and report what's unclear instead of guessing through it (in an unattended run, record the ambiguity in your report — never block waiting for an answer nobody is there to give).

**Surgical changes.** Touch only what the task requires. Don't "improve" adjacent code, comments, or formatting while in a file for something else, and don't refactor what isn't broken as a side effect. Match existing style even where you'd choose differently. Clean up only what *your* edit made dead; mention pre-existing dead code you notice rather than removing it unasked — unless you are explicitly running a cleanup pass (`/declutter`), whose entire job is removing pre-existing dead code under its own evidence gate."""

subs["HOUSE_RULES"] = CODING_DISCIPLINE + "\n\n" + house_rules
subs["HOUSE_RULES_BULLETS"] = house_rules
```

Note the two carve-outs baked into the wording — both fix real conflicts found during verification, so do not paraphrase them away: the unattended clause prevents a contradiction with `loop.md`'s unattended mode (where an `ask`-style block "would hang forever with nobody to answer it"), and the `/declutter` clause prevents every legitimate declutter commit from reading as a rule violation.

- [ ] **Step 3: Verify the embedded Python still compiles**

```bash
cd /Users/aditya/Downloads/Idea/harness-forge
awk '/^python3 - <<.PY./{flag=1; next} /^PY$/{if(flag){flag=0}} flag' plugins/forge/skills/forge/scripts/bootstrap.sh > /tmp/bs-check.py
python3 -m py_compile /tmp/bs-check.py && echo "EMBEDDED PYTHON OK"
rm -f /tmp/bs-check.py
```
Expected: `EMBEDDED PYTHON OK`. (This extract-and-compile technique is how the embedded block has been syntax-checked before in this repo — a syntax error here breaks every install, and the outer `bash -n` cannot see inside a quoted heredoc.)

- [ ] **Step 4: Verify the content lands in agents on a FRESH install, and that CLAUDE.md is untouched**

```bash
cd /Users/aditya/Downloads/Idea/harness-forge
rm -rf /tmp/r12-fresh && mkdir -p /tmp/r12-fresh
bash plugins/forge/skills/forge/scripts/bootstrap.sh --target /tmp/r12-fresh \
  --set PROJECT_NAME=Fresh --set PROJECT_DESC="a reasonably typical one-line project description" \
  --set BUILD_CMD=b --set TEST_CMD=t --set LINT_CMD=l --set FMT_CMD=f > /dev/null 2>&1
echo "--- agents carrying the content (expect all 6) ---"
grep -l "Coding discipline" /tmp/r12-fresh/.claude/agents/*.md | xargs -n1 basename
echo "--- CLAUDE.md must NOT carry it (budget-charged file) ---"
grep -c "Coding discipline" /tmp/r12-fresh/CLAUDE.md || echo "0 — correct, CLAUDE.md is clean"
```
Expected: exactly these six filenames — `bug-fixer.md`, `code-reviewer.md`, `security-reviewer.md`, `silent-failure-hunter.md`, `small-executor.md`, `small-verifier.md` — and `0` (or the "correct, CLAUDE.md is clean" fallback) for `CLAUDE.md`. If `CLAUDE.md` contains it, `HOUSE_RULES_BULLETS` was wrongly modified: revert Step 2 and redo it.

- [ ] **Step 5: Verify the UPGRADE path — the failure mode that killed the previous draft**

```bash
cd /Users/aditya/Downloads/Idea/harness-forge
rm -rf /tmp/r12-upgrade && mkdir -p /tmp/r12-upgrade
git stash push plugins/forge/skills/forge/scripts/bootstrap.sh -m "r12-wip" >/dev/null
bash plugins/forge/skills/forge/scripts/bootstrap.sh --target /tmp/r12-upgrade \
  --set PROJECT_NAME=Up --set PROJECT_DESC=d --set BUILD_CMD=b --set TEST_CMD=t --set LINT_CMD=l --set FMT_CMD=f > /dev/null 2>&1
echo "--- pre-upgrade (expect 0 agents) ---"
grep -l "Coding discipline" /tmp/r12-upgrade/.claude/agents/*.md 2>/dev/null | wc -l | tr -d ' '
git stash pop >/dev/null
bash plugins/forge/skills/forge/scripts/bootstrap.sh --target /tmp/r12-upgrade \
  --set PROJECT_NAME=Up --set PROJECT_DESC=d --set BUILD_CMD=b --set TEST_CMD=t --set LINT_CMD=l --set FMT_CMD=f 2>&1 | grep "^mode:"
echo "--- post-upgrade (expect 6 agents) ---"
grep -l "Coding discipline" /tmp/r12-upgrade/.claude/agents/*.md | wc -l | tr -d ' '
```
Expected: `0`, then `mode: upgrade`, then `6`. This proves the content reaches **already-forged projects**, which the previous draft could not do.

If `git stash push` reports nothing to stash, you have uncommitted changes elsewhere or already committed Step 2 — resolve that before running this step; do not skip it, this is the step that validates the plan's core design claim.

- [ ] **Step 6: Confirm the always-loaded budget is genuinely unchanged**

```bash
bash /tmp/r12-fresh/.claude/scripts/context-budget.sh | tail -3
```
Expected: `VERDICT: NEAR LIMIT (1202)` — i.e. **byte-identical to the pre-change baseline**, because this plan adds no rules file and does not touch `CLAUDE.md`. If the number moved at all, `HOUSE_RULES_BULLETS` was contaminated — fix Step 2.

- [ ] **Step 7: Run the full invariant suite, then commit**

```bash
bash plugins/forge/skills/forge/scripts/validate.sh --target /tmp/r12-fresh
bash /tmp/r12-fresh/.claude/scripts/self-check.sh
rm -rf /tmp/r12-fresh /tmp/r12-upgrade
git add plugins/forge/skills/forge/scripts/bootstrap.sh
git commit -m "$(cat <<'EOF'
bootstrap.sh (R12): inject coding-discipline into HOUSE_RULES, not a rules file

Think-before-coding + surgical-changes now ride the {{HOUSE_RULES}}
substitution — the only channel already injected into all six isolated
agents AND propagated on upgrade (agents/ is harness-code zone; CLAUDE.md
is copy-only-if-absent, so a pointer there never reaches an existing
project).

Kept out of HOUSE_RULES_BULLETS deliberately: that feeds CLAUDE.md, which
is budget-charged. Always-loaded total is unchanged at 1202 tokens, versus
~1448-of-1500 under the earlier rules-file design once a project's real
house rules are populated.

Wording carries two carve-outs for conflicts found in verification: the
unattended-run clause (loop.md's unattended mode cannot block on an ask)
and the /declutter clause (removing pre-existing dead code is that
skill's actual job).
EOF
)"
```
Expected: both suites all-pass before committing.

---

### Task 2: Close `small-executor.md`'s assumption gap **without** weakening its Stop hook

**Files:**
- Modify: `plugins/forge/skills/forge/templates/dotclaude/agents/small-executor.md`

**Interfaces:**
- Consumes: nothing from Task 1 (that content arrives by substitution at install time; this task edits the prose/frontmatter around it).

- [ ] **Step 1: Read the file and confirm both anchors**

Run: `cat plugins/forge/skills/forge/templates/dotclaude/agents/small-executor.md`

Confirm the Stop-hook `prompt:` line currently reads exactly (note `without either ... or ...` — a **disjunctive** block condition):
```
          prompt: "This worker agent was given one narrow implementation step. Review its transcript in $ARGUMENTS. Respond {\"decision\": \"block\", \"reason\": \"<what is missing>\"} if it is stopping without either (a) reporting the exact verification commands it ran and their results, or (b) explicitly declaring the step failed and why. Respond {} otherwise."
```
And that Protocol step 2 reads exactly:
```
2. **Restate the step** in one sentence, including its done-condition. If the step as given is actually multiple steps, say so and stop — decomposition is the orchestrator's job, and an overloaded step is how small models fail.
```
If either doesn't match, STOP and report NEEDS_CONTEXT.

- [ ] **Step 2: Rewrite the Stop-hook prompt as TWO INDEPENDENT block conditions**

This is the correctness-critical edit in this plan. The existing gate blocks when verification evidence is missing. The new condition must be **additive** — an independent second reason to block — never a clause that has to *also* be true. Replace the `prompt:` line with:

```yaml
          prompt: "This worker agent was given one narrow implementation step. Review its transcript in $ARGUMENTS. Respond {\"decision\": \"block\", \"reason\": \"<what is missing>\"} if EITHER of these is true, judged independently: (1) it is stopping without reporting the exact verification commands it ran and their results, AND without explicitly declaring the step failed and why; (2) the step's intent was genuinely ambiguous (not merely under-specified in an obviously-inferable way) and it neither stated the assumption it made nor flagged the ambiguity in its report. Respond {} otherwise."
```

- [ ] **Step 3: Prove the gate did not get weaker — semantic check, not just a parse check**

A YAML-parses check cannot catch a logic inversion (this is precisely how the previous draft's regression slipped through review). Verify the semantics explicitly:

```bash
cd /Users/aditya/Downloads/Idea/harness-forge
python3 - << 'PY'
import re, yaml
text = open('plugins/forge/skills/forge/templates/dotclaude/agents/small-executor.md').read()
fm = yaml.safe_load(re.match(r'^---\n(.*?)\n---\n', text, re.DOTALL).group(1))
p = fm['hooks']['Stop'][0]['hooks'][0]['prompt']
# The original gate's guarantee: missing verification evidence alone must be enough to block.
assert 'EITHER' in p, "block conditions are not disjunctive"
assert 'judged independently' in p, "independence of the two conditions is not stated"
assert p.count('(1)') == 1 and p.count('(2)') == 1, "expected exactly two numbered conditions"
# Condition (1) must itself be the AND of 'no evidence' and 'no failure declaration',
# i.e. the ORIGINAL semantics preserved intact inside condition 1.
c1 = p.split('(1)')[1].split('(2)')[0]
assert 'without reporting the exact verification commands' in c1
assert 'without explicitly declaring the step failed' in c1
assert ' AND ' in c1, "condition (1) must require BOTH absences, matching the original gate"
print("SEMANTIC CHECK PASSED: verification-evidence gate preserved, assumption check added independently")
PY
```
Expected: `SEMANTIC CHECK PASSED: ...`. If any assertion fails, the edit is wrong — re-read Step 2 and redo it. Do not proceed with a failing assertion.

- [ ] **Step 4: Add assumption-surfacing to Protocol step 2**

Replace the Protocol step 2 line from Step 1 with:
```
2. **Restate the step** in one sentence, including its done-condition. If the step as given is actually multiple steps, say so and stop — decomposition is the orchestrator's job, and an overloaded step is how small models fail. If the step's intent is genuinely ambiguous (not merely under-specified in an obviously-inferable way), state the assumption you're making in your final `NOTES:` — don't silently guess and proceed as if there were only one reading.
```

Note what this task deliberately does NOT add: Protocol steps 3 ("Reason in prose first, then act") and 4 ("Implement the minimum change for this step only") already cover the rest of both principles for this agent, and Task 1's substitution now delivers the full statement anyway. Adding more here would be the duplication this design avoids.

- [ ] **Step 5: Verify frontmatter parses and commit**

```bash
python3 -c "
import re, yaml
t = open('plugins/forge/skills/forge/templates/dotclaude/agents/small-executor.md').read()
m = re.match(r'^---\n(.*?)\n---\n', t, re.DOTALL); assert m, 'frontmatter malformed'
yaml.safe_load(m.group(1)); print('frontmatter OK')
"
git add plugins/forge/skills/forge/templates/dotclaude/agents/small-executor.md
git commit -m "$(cat <<'EOF'
small-executor.md (R12): add assumption check as an INDEPENDENT Stop condition

The Stop hook now blocks on EITHER missing verification evidence (the
original guarantee, preserved intact) OR an unstated assumption on a
genuinely ambiguous step. An earlier draft of this change accidentally
made the two conjunctive, which would have let an agent reporting zero
verification evidence pass the gate as long as it stated an assumption —
in elevate.js that gate is the only thing between a Haiku "done!" and the
verifier panel. Guarded by an explicit semantic assertion (a
YAML-parses check cannot catch a logic inversion).
EOF
)"
```

---

### Task 3: Regression check — assert the content reaches every agent surface

**Files:**
- Create: `plugins/forge/skills/forge/templates/dotclaude/evals/regressions/0005-coding-discipline-reaches-every-agent.sh`

**Interfaces:**
- Consumes: Task 1's substitution (this check fails until Task 1 is committed — correct TDD ordering, verified in Step 2 below).
- Produces: a CI-gated invariant. `evals/regressions/run-all.sh` auto-discovers `[0-9][0-9][0-9][0-9]-*.sh` (verified), so no runner changes are needed.

- [ ] **Step 1: Create the check**

Create `plugins/forge/skills/forge/templates/dotclaude/evals/regressions/0005-coding-discipline-reaches-every-agent.sh`:

```bash
#!/usr/bin/env bash
# Regression check: the coding-discipline house rules (ROADMAP R12) must reach EVERY
# isolated agent. These agents cannot see .claude/rules/*.md — they only get the
# {{HOUSE_RULES}} substitution — so if a future edit moves this content into a rules
# file, renames the marker, or drops {{HOUSE_RULES}} from an agent, that agent silently
# loses the rules with no other symptom. This check is the mechanical replacement for
# "remember to keep six copies in sync."
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

MARKER="## Coding discipline"
AGENTS="small-executor bug-fixer code-reviewer small-verifier security-reviewer silent-failure-hunter"

failed=0
for name in $AGENTS; do
  f=".claude/agents/${name}.md"
  if [ ! -f "$f" ]; then
    echo "missing agent file: $f"
    failed=1
    continue
  fi
  if ! grep -qF "$MARKER" "$f"; then
    echo "$f: no '$MARKER' section — this agent is not receiving the R12 house rules"
    failed=1
  fi
done

# Both halves must be present, not just the heading.
for phrase in "Think before coding" "Surgical changes"; do
  if ! grep -qF "$phrase" ".claude/agents/small-executor.md"; then
    echo "small-executor.md: missing '$phrase' — the injected block is incomplete"
    failed=1
  fi
done

exit $failed
```

- [ ] **Step 2: Prove the check actually fails without Task 1 (red-green — a check that can't fail proves nothing)**

```bash
cd /Users/aditya/Downloads/Idea/harness-forge
chmod +x plugins/forge/skills/forge/templates/dotclaude/evals/regressions/0005-coding-discipline-reaches-every-agent.sh

# RED: install from a tree WITHOUT Task 1's bootstrap change, then run the new check against it
rm -rf /tmp/r12-red && mkdir -p /tmp/r12-red
git stash push plugins/forge/skills/forge/scripts/bootstrap.sh -m "r12-red-test" >/dev/null 2>&1 \
  && STASHED=1 || STASHED=0
bash plugins/forge/skills/forge/scripts/bootstrap.sh --target /tmp/r12-red \
  --set PROJECT_NAME=Red --set PROJECT_DESC=d --set BUILD_CMD=b --set TEST_CMD=t --set LINT_CMD=l --set FMT_CMD=f > /dev/null 2>&1
cp plugins/forge/skills/forge/templates/dotclaude/evals/regressions/0005-coding-discipline-reaches-every-agent.sh \
   /tmp/r12-red/.claude/evals/regressions/
bash /tmp/r12-red/.claude/evals/regressions/0005-coding-discipline-reaches-every-agent.sh
echo "RED exit code: $? (MUST be non-zero)"
[ "$STASHED" = "1" ] && git stash pop >/dev/null
```
Expected: the check prints "not receiving the R12 house rules" lines and a **non-zero** exit code. If Task 1 is already committed (so `git stash push` found nothing to stash), this RED step cannot run as written — in that case verify equivalently by temporarily emptying one agent's `{{HOUSE_RULES}}` line in a `/tmp` copy of the installed project and confirming the check fails on it. Do not skip the red phase; report which variant you used.

- [ ] **Step 3: GREEN — the same check passes with Task 1 in place**

```bash
cd /Users/aditya/Downloads/Idea/harness-forge
rm -rf /tmp/r12-green && mkdir -p /tmp/r12-green
bash plugins/forge/skills/forge/scripts/bootstrap.sh --target /tmp/r12-green \
  --set PROJECT_NAME=Green --set PROJECT_DESC=d --set BUILD_CMD=b --set TEST_CMD=t --set LINT_CMD=l --set FMT_CMD=f > /dev/null 2>&1
bash /tmp/r12-green/.claude/evals/regressions/0005-coding-discipline-reaches-every-agent.sh
echo "GREEN exit code: $? (MUST be 0)"
echo "--- and via the shared runner (expect 5 checks passing) ---"
bash /tmp/r12-green/.claude/evals/regressions/run-all.sh
```
Expected: exit `0`, and `REGRESSIONS: 5 passed, 0 failed` from the runner (4 pre-existing + this one). Note the check must be run from an *installed* project, not the raw template tree — every check in this directory resolves `.claude/...` paths that only exist post-install (an established convention here, matching checks 0001–0004).

- [ ] **Step 4: Confirm the exec bit survives installation, then clean up and commit**

```bash
ls -l /tmp/r12-green/.claude/evals/regressions/0005-coding-discipline-reaches-every-agent.sh
rm -rf /tmp/r12-red /tmp/r12-green
git add plugins/forge/skills/forge/templates/dotclaude/evals/regressions/0005-coding-discipline-reaches-every-agent.sh
git commit -m "$(cat <<'EOF'
Add regression 0005: R12 house rules must reach every isolated agent

Mechanical replacement for "remember to keep the wording in sync across
six surfaces." These agents can't see rules/*.md, so an agent silently
losing {{HOUSE_RULES}} has no other symptom. Red-green verified: fails
against an install without the bootstrap.sh change, passes with it.

Satisfies GUIDE.md §5's requirement that a Zone B change ship a test.
EOF
)"
```
Expected: the installed file shows an executable bit (`-rwxr-xr-x`). If not, `validate.sh`'s exec-bit check would have caught it in Task 5 anyway, but fix it now with `chmod +x` on the template and re-verify.

---

### Task 4: Route scope-creep findings to `consider` so `review-diff.js` can't refute them away

**Files:**
- Modify: `plugins/forge/skills/forge/templates/dotclaude/agents/code-reviewer.md`

**Interfaces:**
- Consumes: Task 1's substitution (which is what makes `code-reviewer` aware of the principles at all).
- Produces: scope-creep findings that survive `review-diff.js`'s refuter phase by bypassing it.

- [ ] **Step 1: Read both files and confirm the anchors**

```bash
cat plugins/forge/skills/forge/templates/dotclaude/agents/code-reviewer.md
grep -n "REFUTE" plugins/forge/skills/forge/templates/dotclaude/workflows/review-diff.js
```

Confirm `code-reviewer.md`'s `## Operating principles` last bullet reads exactly:
```
- Surgical scope: review only the changed lines and their immediate blast radius, not the whole file.
```
And confirm `review-diff.js`'s refuter prompt contains `default to refuted=true if uncertain` and passes only the finding string (no task/intent context). This is *why* this task exists: a scope-creep blocker is unconfirmable from code alone, so uncertainty — and therefore refutation — is its default outcome. If either anchor differs, STOP and report NEEDS_CONTEXT.

- [ ] **Step 2: Add the routing rule**

Add this bullet immediately after the `- Surgical scope: ...` bullet:
```
- Scope creep goes in **Consider**, never Blockers: note changed lines that don't trace to the stated task (unrelated refactors, formatting-only edits to untouched code, style drift). Route it to Consider even at high confidence — a downstream refuter pass is given only the finding text and defaults to rejecting what it can't confirm from code alone, and "this doesn't match the task's intent" is exactly that. Consider-items bypass that pass and reach the human.
```

- [ ] **Step 3: Verify frontmatter parses and commit**

```bash
python3 -c "
import re, yaml
t = open('plugins/forge/skills/forge/templates/dotclaude/agents/code-reviewer.md').read()
m = re.match(r'^---\n(.*?)\n---\n', t, re.DOTALL); assert m, 'frontmatter malformed'
yaml.safe_load(m.group(1)); print('frontmatter OK')
"
git add plugins/forge/skills/forge/templates/dotclaude/agents/code-reviewer.md
git commit -m "$(cat <<'EOF'
code-reviewer.md (R12): route scope-creep findings to Consider, not Blockers

review-diff.js sends every blocker through three refuters prompted to
"default to refuted=true if uncertain," given only the finding string —
no task description. "This change doesn't trace to the stated task" is
unconfirmable from code alone, so scope-creep blockers would be refuted
at near-100%. Consider-items bypass the refuter phase and reach the
human, so that's where these belong.
EOF
)"
```

---

### Task 5: Mark R12 done, file the deferred hook as R14, record the decision, bump the version, push

**Files:**
- Modify: `ROADMAP.md`
- Modify: `plugins/forge/skills/forge/templates/dotclaude/memory/decisions.md`
- Modify: `plugins/forge/.claude-plugin/plugin.json`

**Interfaces:**
- Consumes: the full shipped state from Tasks 1–4.

- [ ] **Step 1: Update R12's section in `ROADMAP.md`**

Read `grep -n "^## R12" ROADMAP.md` and the section through its closing `---` first; if it no longer matches (title ending `(priority: 3rd)`, Problem/Correction/What's-new/Proposed-approach structure), STOP and report NEEDS_CONTEXT.

Replace the heading:
```
## R12 — Adopt Karpathy's "Think Before Coding" + "Surgical Changes" as new house rules; explicitly skip the rest (priority: 3rd)
```
with:
```
## R12 — Adopt Karpathy's "Think Before Coding" + "Surgical Changes" as new house rules; explicitly skip the rest — ✅ Done
```

Then insert this immediately after the existing `**Proposed approach.**` paragraph, before the closing `---`:

```markdown

**What shipped — one substitution, not a rules file.** The proposed approach above (a new `rules/` file) was designed, then rejected during independent verification, and the reasons are worth keeping: the six agents that actually write and review code in this harness run in isolated contexts and never see `rules/*.md`; `CLAUDE.md` is copy-only-if-absent, so a pointer added there never reaches an already-forged project (the rules file would land as an orphan `/harness-audit` then proposes retiring); and always-loaded budget measured with *real* house rules populated came to ~1448 of a 1500 hard cap, i.e. one modest edit from turning CI red in projects that changed nothing. Shipped instead: the content rides the `{{HOUSE_RULES}}` substitution in `bootstrap.sh` — the one channel injected into all six isolated agents *and* propagated on upgrade (`agents/` is harness-code zone) — kept out of `HOUSE_RULES_BULLETS` so `CLAUDE.md`'s budget is untouched (verified unchanged at 1202 tokens). `evals/regressions/0005-*.sh` CI-gates presence on every agent surface, red-green verified. `small-executor.md`'s Stop hook gained an *independent* second block condition for unstated assumptions on genuinely-ambiguous steps (an earlier draft made the two conditions conjunctive, which would have let an agent with zero verification evidence pass — caught in verification, guarded now by an explicit semantic assertion). `code-reviewer.md` routes scope-creep to Consider, since `review-diff.js`'s refuters default to rejecting findings they can't confirm from code alone.

**Honest scope.** Presence on every surface is mechanically enforced; assumption-surfacing on `small-executor` is LLM-judged via its Stop hook (weaker than a deterministic gate, and not claimed otherwise); the rest is advisory. A deterministic "every changed file traces to the task" gate was deliberately *not* shipped — see R14.
```

- [ ] **Step 2: Verify the section structure is intact**

Run: `grep -c "^## R" ROADMAP.md`
Expected: `13` at this point (R14 is added in the next step).

- [ ] **Step 3: Add R14 for the deferred deterministic gate**

Insert this immediately before `## Contributing` in `ROADMAP.md`:

```markdown
## R14 — Make "surgical changes" deterministically enforceable (needs a machine-parseable `Files:` contract first)

**Problem.** R12 shipped "surgical changes" as advisory prose. The mechanically-enforceable version — a `PostToolUse` hook comparing the session's cumulative `git diff --name-only` against the file list declared by the active `TASKS.md` entry — was designed during R12 and deliberately not shipped, because the prerequisite doesn't exist yet: `tasks/TASKS.md`'s `Files:` field is freeform prose (the shipped template literally reads `Files: (expected files)`). Diffing against prose produces false positives, and a gate that cries wolf gets disabled — worse than no gate.

**Proposed approach.** First define a machine-parseable contract for the `Files:` field (e.g. a comma- or space-separated glob list, validated by `self-check.sh` so drift is caught immediately). Then the hook is straightforward and follows `capability-gate.sh`'s established shape: deterministic detection, a block-path and an allow-path fixture, and a `state/` marker so it nudges once per session rather than on every edit. Note the honest ceiling: this can only ever enforce the *surgical changes* half of R12 — "state your assumptions when intent is genuinely ambiguous" is irreducibly a judgment call and no hook can decide it.

**Open question.** Is a stricter `Files:` contract worth the friction it adds to every task entry? An alternative is scoping the gate to tasks that opt in by declaring a parseable list, leaving prose entries ungated.

---
```

Then re-verify: `grep -c "^## R" ROADMAP.md` → expected `14`.

- [ ] **Step 4: Confirm the always-loaded budget is unchanged from baseline**

```bash
cd /Users/aditya/Downloads/Idea/harness-forge
rm -rf /tmp/r12-budget && mkdir -p /tmp/r12-budget
bash plugins/forge/skills/forge/scripts/bootstrap.sh --target /tmp/r12-budget \
  --set PROJECT_NAME=BudgetCheck --set PROJECT_DESC="a reasonably typical one-line project description" \
  --set BUILD_CMD=b --set TEST_CMD=t --set LINT_CMD=l --set FMT_CMD=f > /dev/null 2>&1
bash /tmp/r12-budget/.claude/scripts/context-budget.sh | tail -2
```
Expected: `1202 tok TOTAL` and `VERDICT: NEAR LIMIT (1202)` — identical to the pre-R12 baseline. This is the claim the ROADMAP text above asserts; do not write it as fact if the real output differs.

- [ ] **Step 5: Record the decision (GUIDE.md §5's third requirement for a Zone B change)**

Read the file's last few lines first (`tail -5`) to confirm its documented entry format is still `**[YYYY-MM-DD] — decision — why:** rationale.` — the existing seed entry uses `**[{{DATE}}] — ... — why:** ...`, and the new entry must match that shape, not a bullet list.

Append to `plugins/forge/skills/forge/templates/dotclaude/memory/decisions.md`:

```markdown

**[{{DATE}}] — R12 coding-discipline rides the `{{HOUSE_RULES}}` substitution, not a `rules/*.md` file — why:** the six isolated agents never see `rules/*.md`; `CLAUDE.md` is copy-only-if-absent, so a pointer added there never reaches an already-forged project; and an always-loaded rules file measured ~1448 of a 1500 hard cap once a project's real house rules are populated. `{{HOUSE_RULES}}` is the only channel that reaches all six agents *and* survives upgrades (`agents/` is harness-code zone). Kept out of `HOUSE_RULES_BULLETS` so `CLAUDE.md`'s budget stays untouched. Presence is CI-gated by `evals/regressions/0005-coding-discipline-reaches-every-agent.sh`. Deterministic diff-scope enforcement was deferred to R14 pending a machine-parseable `TASKS.md` `Files:` contract — don't "simplify" this into a rules file without re-reading those four reasons.
```

Two things verified about this: `{{DATE}}` **is** in `bootstrap.sh`'s standard substitution set (`bootstrap.sh:75`) and the existing seed entry already uses it, so write the literal placeholder rather than today's date. But note `memory/` **is** in `USER_DATA_PREFIXES` (`bootstrap.sh:111`) — so this entry only reaches *new* installs; existing projects keep their own `decisions.md` untouched (correct behavior: it's their knowledge file, not ours to rewrite). That's why Task 5 Step 7 checks for leftover `{{DATE}}` on a fresh install specifically.

- [ ] **Step 6: Bump the plugin version**

```bash
python3 -c "
import json; print('current:', json.load(open('plugins/forge/.claude-plugin/plugin.json'))['version'])
"
```
Then (adjust the target if the printed current version isn't `1.5.1`):
```bash
python3 -c "
import json
p = 'plugins/forge/.claude-plugin/plugin.json'
d = json.load(open(p)); d['version'] = '1.6.0'
json.dump(d, open(p, 'w'), indent=2); print('bumped to', d['version'])
"
```
Minor bump, not patch: this adds a new always-injected behavior plus a new regression check, not a bugfix.

- [ ] **Step 7: Full end-to-end verification at the bumped version**

```bash
cd /Users/aditya/Downloads/Idea/harness-forge
rm -rf /tmp/r12-final && mkdir -p /tmp/r12-final
bash plugins/forge/skills/forge/scripts/bootstrap.sh --target /tmp/r12-final \
  --set PROJECT_NAME=F --set PROJECT_DESC=d --set BUILD_CMD=b --set TEST_CMD=t --set LINT_CMD=l --set FMT_CMD=f > /dev/null 2>&1
bash plugins/forge/skills/forge/scripts/validate.sh --target /tmp/r12-final
bash /tmp/r12-final/.claude/scripts/self-check.sh
echo "--- all 6 agents carry it ---"
grep -l "Coding discipline" /tmp/r12-final/.claude/agents/*.md | wc -l | tr -d ' '
echo "--- decisions.md has no leftover placeholder ---"
grep -c "{{DATE}}" /tmp/r12-final/.claude/memory/decisions.md || echo "0 — substituted correctly"
echo "--- version ---"
python3 -c "import json; print(json.load(open('/tmp/r12-final/.claude/forge-manifest.json'))['forge_version'])"
rm -rf /tmp/r12-final /tmp/r12-budget
```
Expected: both suites all-pass (`REGRESSIONS: 5 passed, 0 failed` inside them), `6` agents, `0` leftover `{{DATE}}` placeholders, and the bumped version. A leftover `{{DATE}}` would also fail `validate.sh`'s placeholder check — if it does, `decisions.md` may be excluded from substitution as user-data; in that case write an ISO date literal instead and note the deviation.

- [ ] **Step 8: Commit and push**

```bash
git add ROADMAP.md plugins/forge/skills/forge/templates/dotclaude/memory/decisions.md \
        plugins/forge/.claude-plugin/plugin.json
git commit -m "$(cat <<'EOF'
forge 1.6.0: R12 done via HOUSE_RULES; file R14 for the deterministic gate

R12's ROADMAP entry records what shipped, why the rules-file approach was
rejected in verification, and an explicit honest-scope note (what's
mechanically enforced vs. LLM-judged vs. advisory) rather than implying
prose equals enforcement.

R14 files the deferred deterministic diff-scope hook with its real
blocker named: TASKS.md's Files: field is freeform prose, so a gate
built on it would false-positive, and a gate that cries wolf gets
disabled.

decisions.md records the Zone B rationale per GUIDE.md §5.
EOF
)"
git push origin master
```

---

## Final verification (after all five tasks)

- [ ] `git log --oneline -6` — five new commits (Tasks 1–5), each independently reviewable.
- [ ] `git status --short` — clean tree.
- [ ] `git rev-list --left-right --count origin/master...master` — `0 0`.
- [ ] Re-run the semantic Stop-hook assertion from Task 2 Step 3 one final time against the committed file — it is the single edit in this plan whose silent failure would degrade an existing safety gate, so confirm it at the end as well as mid-flight.
- [ ] Confirm on a fresh install that `evals/regressions/run-all.sh` reports `5 passed, 0 failed` and `context-budget.sh` reports `1202` — the two numbers this plan's ROADMAP text asserts publicly.
