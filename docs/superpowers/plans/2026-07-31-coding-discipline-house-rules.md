# Coding Discipline House Rules (R12) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship ROADMAP.md's R12 — "Think before coding" + "Surgical changes" — as content that actually reaches every place code gets written or reviewed in this harness, not just the main session's own direct edits.

**Architecture:** Multi-surface, not single-file. A first design (kept as Task 1) added one `rules/coding-discipline.md` pointed to from `CLAUDE.md.tmpl` — but every agent that actually writes or reviews code in this harness (`small-executor.md`, `bug-fixer.md`, `code-reviewer.md`, `security-reviewer.md`, `silent-failure-hunter.md`, `small-verifier.md`) explicitly "runs in an isolated context and do[es] not see this project's CLAUDE.md, rules, or memory" — confirmed by reading all six files directly. `rules/*.md` content is invisible to all of them; they only see `{{HOUSE_RULES}}`, a *different* substitution (project-specific conventions `/forge` scans from real source files, wired in `bootstrap.sh`, zero connection to `rules/*.md`). Since most actual code-writing in this harness happens through these agents (`elevate.js`'s cascade, `implement-tasks.js`, the whole-branch review flow used for R1+R10), a rules-file-only design would have delivered close to zero real enforcement. This plan instead:
1. Keeps `rules/coding-discipline.md` for the main session (Task 1).
2. Adds targeted content to the two agents that actually write code in isolated contexts (Task 2, Task 3) — precisely scoped, since both files already cover parts of this (reusing what exists, not duplicating it).
3. Adds an explicit review-check item to the three surfaces that review code quality (Task 4) — converts "hope the implementer stayed surgical" into "the reviewer actively checks and flags it."
4. Documents the resulting multi-surface wiring in `GUIDE.md` so a future maintainer touching one surface knows to check the others (Task 5).

**Tech Stack:** Plain markdown/YAML agent-definition files, no new hook types — Task 2 extends an *existing, already-proven* `type: prompt` Stop hook rather than inventing a new enforcement mechanism.

## Global Constraints

- Do not bulk-import the source repo's `CLAUDE.md` (`multica-ai/andrej-karpathy-skills`). Only "Think before coding" and "Surgical changes," in this harness's own voice.
- **Verified: agent files (`.claude/agents/*.md`) do not count against the always-loaded context budget.** `context-budget.sh` globs only `["CLAUDE.md"] + glob.glob(".claude/rules/*.md")` (confirmed by reading the script directly) — Tasks 2-4 are free against that gate. Only Task 1's `rules/coding-discipline.md` addition costs budget.
- Task 1's exact content was measured by hand: grand total **1335 tokens** (target ≤1200, hard cap ≤1500 — "NEAR LIMIT," accepted as-is; do not cut `ship-verification.md`'s rationale sentence or gut real content to force a lower number).
- **Before editing any of the 6 agent files below, read the current file first** — several already partially cover these principles (confirmed by reading all six during design), and this plan's additions are deliberately the *precise remaining gap*, not a restated duplicate. If the file you read doesn't match what a task assumes, stop and report NEEDS_CONTEXT rather than layering a redundant addition on top.
- `security-reviewer.md` and `silent-failure-hunter.md` get **no changes** — their job is a different, specific concern (security, silent-error-handling), and adding a general scope-creep check to their prompts would itself be the kind of scope creep this plan is trying to prevent.

---

### Task 1: Add `coding-discipline.md`, trim `git-workflow.md`, wire the pointer, verify the budget

**Files:**
- Create: `plugins/forge/skills/forge/templates/dotclaude/rules/coding-discipline.md`
- Modify: `plugins/forge/skills/forge/templates/dotclaude/rules/git-workflow.md`
- Modify: `plugins/forge/skills/forge/templates/CLAUDE.md.tmpl`

**Interfaces:**
- Produces: `.claude/rules/coding-discipline.md` in every forged project (installed by the existing `bootstrap.sh` template-copy loop — no bootstrap.sh changes needed).
- Consumes: nothing from earlier tasks (this is the first task).

- [ ] **Step 1: Create the new rules file with this exact content**

Create `plugins/forge/skills/forge/templates/dotclaude/rules/coding-discipline.md`:

```markdown
# Coding discipline

## Think before coding

- State non-obvious assumptions up front — don't silently pick one interpretation and run with it.
- Name the readings when genuinely ambiguous; pick the sensible default and flag it, don't guess silently.
- Say so if a simpler approach exists than the one implied.
- Stop and ask when genuinely confused — never guess through real uncertainty.

## Surgical changes

- Touch only what the task requires.
- Don't "improve" adjacent code, comments, or formatting while in a file for something else; don't refactor what isn't broken as a side effect.
- Match existing style even where you'd choose differently.
- Clean up only what *your* edit made dead; mention pre-existing dead code you notice, don't remove it unasked.
```

- [ ] **Step 2: Verify the new file's own token count**

Run:
```bash
python3 -c "
t = open('plugins/forge/skills/forge/templates/dotclaude/rules/coding-discipline.md', encoding='utf-8').read()
print((len(t)+3)//4)
"
```
Expected: `192` (a few tokens either way from whitespace is fine; if off by more than ~10, re-check you copied Step 1 verbatim, not paraphrased).

- [ ] **Step 3: Trim `git-workflow.md`'s redundant Safety section**

Read the current file first (`plugins/forge/skills/forge/templates/dotclaude/rules/git-workflow.md`) to confirm it still has a `## Safety (hook-enforced, restated)` section between `## Commit messages` and `## Worktrees`. Replace the entire file with this exact content (that section removed, nothing else changes):

```markdown
# Git workflow

## Branch naming

`feature/{name}` · `fix/{name}` · `refactor/{name}` · `chore/{name}`. Reference a `TASKS.md` ID in the branch/commit body where useful.

## Commit messages

Conventional Commits: `{type}({scope}): {description}`, types `feat|fix|refactor|docs|test|chore`.

## Worktrees

For parallel/risky work where one line of work shouldn't destabilize another: `claude --worktree <name>` or the `EnterWorktree` tool instead of stashing; code-writing subagents can carry `isolation: worktree`. Full guidance in `.claude/GUIDE.md`.
```

If the file you read does NOT have that section (already trimmed, or genuinely differs), STOP and report NEEDS_CONTEXT rather than guessing.

- [ ] **Step 4: Add the pointer in `CLAUDE.md.tmpl`**

In `plugins/forge/skills/forge/templates/CLAUDE.md.tmpl`, find this exact line (under `## Pointers`):
```
- **Rules** (`.claude/rules/`): `safety.md`, `ship-verification.md`, `git-workflow.md`.
```
Replace with:
```
- **Rules** (`.claude/rules/`): `safety.md`, `ship-verification.md`, `git-workflow.md`, `coding-discipline.md`.
```

- [ ] **Step 5: Verify the full budget, end to end, on a fresh install**

```bash
rm -rf /tmp/r12-verify
mkdir -p /tmp/r12-verify
bash plugins/forge/skills/forge/scripts/bootstrap.sh --target /tmp/r12-verify \
  --set PROJECT_NAME=R12Verify --set PROJECT_DESC="a reasonably typical one-line project description" \
  --set BUILD_CMD=b --set TEST_CMD=t --set LINT_CMD=l --set FMT_CMD=f > /tmp/r12-bootstrap.log 2>&1
tail -5 /tmp/r12-bootstrap.log
bash /tmp/r12-verify/.claude/scripts/context-budget.sh
```
Expected: 5 files listed (`CLAUDE.md`, `coding-discipline.md`, `ship-verification.md`, `safety.md`, `git-workflow.md`), total around **1335 tokens**, `VERDICT: NEAR LIMIT (...)`. This is expected and accepted — report the real number, don't chase further cuts.

- [ ] **Step 6: Run the full invariant suite**

```bash
bash plugins/forge/skills/forge/scripts/validate.sh --target /tmp/r12-verify
bash /tmp/r12-verify/.claude/scripts/self-check.sh
```
Expected: both all-pass (`VALIDATE: all checks passed`, `SELF-CHECK: all invariants pass`) — context budget shows `ok` even at NEAR LIMIT (only OVER BUDGET fails `self-check.sh`). Hook fixture/regression counts should be unchanged from HEAD before this task (this task touches no hooks/regressions).

- [ ] **Step 7: Clean up and commit**

```bash
rm -rf /tmp/r12-verify /tmp/r12-bootstrap.log
git add plugins/forge/skills/forge/templates/dotclaude/rules/coding-discipline.md \
        plugins/forge/skills/forge/templates/dotclaude/rules/git-workflow.md \
        plugins/forge/skills/forge/templates/CLAUDE.md.tmpl
git commit -m "$(cat <<'EOF'
Add rules/coding-discipline.md (R12 pt.1): Think before coding + Surgical changes

Main-session-facing half of R12 — see later commits in this series for
the agent-level enforcement, since this file alone is invisible to
every code-writing/reviewing subagent in this harness.

git-workflow.md's redundant "Safety (hook-enforced, restated)" section
removed (pure duplication of rules/safety.md) to partially offset the
new file's context-budget cost. Always-loaded budget: 1335 tokens
(NEAR LIMIT, target <=1200, hard cap <=1500) on a fresh install —
accepted as-is rather than cutting real content for a lower number.
EOF
)"
```

---

### Task 2: `small-executor.md` — state assumptions when genuinely ambiguous, extend the existing Stop hook

**Files:**
- Modify: `plugins/forge/skills/forge/templates/dotclaude/agents/small-executor.md`

**Interfaces:**
- Consumes: nothing from Task 1 (agent files are a separate, isolated context — no dependency).

- [ ] **Step 1: Read the current file and confirm it matches this plan's assumption**

Run: `cat plugins/forge/skills/forge/templates/dotclaude/agents/small-executor.md`

Confirm the `## Protocol` section's step 2 currently reads: `**Restate the step** in one sentence, including its done-condition. If the step as given is actually multiple steps, say so and stop — decomposition is the orchestrator's job, and an overloaded step is how small models fail.` and that the YAML frontmatter has a `hooks: Stop:` block with a `type: prompt` hook whose `prompt:` string mentions responding with `{"decision": "block", ...}` when the agent stops without verification evidence or an explicit failure declaration. If either doesn't match, STOP and report NEEDS_CONTEXT.

Note what this task deliberately does NOT touch: Protocol step 3 ("Reason in prose first, then act") and step 4 ("Implement the minimum change for this step only") already cover most of "think before coding" and "surgical changes" respectively — the only genuine gap is assumption-surfacing under real ambiguity, which is what both edits below add.

- [ ] **Step 2: Add assumption-stating to Protocol step 2**

Find this exact line:
```
2. **Restate the step** in one sentence, including its done-condition. If the step as given is actually multiple steps, say so and stop — decomposition is the orchestrator's job, and an overloaded step is how small models fail.
```
Replace with:
```
2. **Restate the step** in one sentence, including its done-condition. If the step as given is actually multiple steps, say so and stop — decomposition is the orchestrator's job, and an overloaded step is how small models fail. If the step's intent is genuinely ambiguous (not merely under-specified in an obviously-inferable way), state the assumption you're making in your final `NOTES:` — don't silently guess and proceed as if there were only one reading.
```

- [ ] **Step 3: Extend the existing Stop hook's prompt to check for this**

Find this exact line in the YAML frontmatter (inside `hooks: Stop: - hooks: - type: prompt`):
```yaml
          prompt: "This worker agent was given one narrow implementation step. Review its transcript in $ARGUMENTS. Respond {\"decision\": \"block\", \"reason\": \"<what is missing>\"} if it is stopping without either (a) reporting the exact verification commands it ran and their results, or (b) explicitly declaring the step failed and why. Respond {} otherwise."
```
Replace with:
```yaml
          prompt: "This worker agent was given one narrow implementation step. Review its transcript in $ARGUMENTS. Respond {\"decision\": \"block\", \"reason\": \"<what is missing>\"} if it is stopping without: (a) reporting the exact verification commands it ran and their results, or explicitly declaring the step failed and why; AND (b) — only if the step's intent was genuinely ambiguous, not merely under-specified in an obviously-inferable way — stating what assumption it made instead of silently guessing. Respond {} otherwise."
```

- [ ] **Step 4: Verify the YAML frontmatter still parses**

```bash
python3 -c "
import re, yaml
text = open('plugins/forge/skills/forge/templates/dotclaude/agents/small-executor.md').read()
m = re.match(r'^---\n(.*?)\n---\n', text, re.DOTALL)
assert m, 'frontmatter missing or malformed'
d = yaml.safe_load(m.group(1))
print('frontmatter OK, keys:', list(d.keys()))
print('stop hook prompt:', d['hooks']['Stop'][0]['hooks'][0]['prompt'][:80], '...')
"
```
Expected: `frontmatter OK, keys: [...]` including `hooks`, and the prompt preview printed without a YAML parse error. If `yaml` isn't installed, run `pip install pyyaml` first — do not skip this check, a broken Stop hook is a silent, high-impact failure (it's what currently guarantees this agent can't silently claim success without verification evidence).

- [ ] **Step 5: Commit**

```bash
git add plugins/forge/skills/forge/templates/dotclaude/agents/small-executor.md
git commit -m "small-executor.md (R12 pt.2): state assumptions under real ambiguity

Extends the existing type:prompt Stop hook (already proven — it's what
blocks this agent from silently claiming success without verification
evidence) to also require stating any assumption made when a step's
intent was genuinely ambiguous. Reuses the proven mechanism rather than
inventing a new one. Protocol steps 3-4 already covered most of
think-before-coding/surgical-changes for this agent; this closes the
one remaining gap."
```

---

### Task 3: `bug-fixer.md` — state assumptions when the bug report itself is ambiguous

**Files:**
- Modify: `plugins/forge/skills/forge/templates/dotclaude/agents/bug-fixer.md`

**Interfaces:**
- Consumes: nothing from earlier tasks.

- [ ] **Step 1: Read the current file and confirm it matches this plan's assumption**

Run: `cat plugins/forge/skills/forge/templates/dotclaude/agents/bug-fixer.md`

Confirm `## Process` step 1 currently reads: `**Reproduce first.** If given a failing test, run it and confirm it fails for the stated reason before touching any code. If not given one, write a test that reproduces the bug before fixing it.` If it doesn't match, STOP and report NEEDS_CONTEXT.

Note what this task deliberately does NOT touch: step 2 ("Smallest fix... no drive-by refactors, no unrelated cleanup... Note anything else you noticed... instead of fixing it") and the closing line ("do not touch files outside the scope of the stated bug") already fully cover "surgical changes" for this agent — this task adds nothing there. The only gap is assumption-stating for an ambiguous bug report.

- [ ] **Step 2: Add assumption-stating to Process step 1**

Find this exact line:
```
1. **Reproduce first.** If given a failing test, run it and confirm it fails for the stated reason before touching any code. If not given one, write a test that reproduces the bug before fixing it.
```
Replace with:
```
1. **Reproduce first.** If given a failing test, run it and confirm it fails for the stated reason before touching any code. If not given one, write a test that reproduces the bug before fixing it. If the bug report itself is ambiguous — unclear expected behavior, or more than one plausible root cause — state your interpretation and which root cause you're pursuing in your final report before proceeding, rather than silently picking one.
```

- [ ] **Step 3: Verify the YAML frontmatter still parses**

```bash
python3 -c "
import re, yaml
text = open('plugins/forge/skills/forge/templates/dotclaude/agents/bug-fixer.md').read()
m = re.match(r'^---\n(.*?)\n---\n', text, re.DOTALL)
assert m, 'frontmatter missing or malformed'
yaml.safe_load(m.group(1))
print('frontmatter OK')
"
```
Expected: `frontmatter OK`.

- [ ] **Step 4: Commit**

```bash
git add plugins/forge/skills/forge/templates/dotclaude/agents/bug-fixer.md
git commit -m "bug-fixer.md (R12 pt.3): state assumptions when the bug report is ambiguous

Surgical-changes was already fully covered here (no drive-by refactors,
note-don't-fix pre-existing issues, worktree-scoped). This closes the
one remaining gap: think-before-coding for an ambiguous repro."
```

---

### Task 4: Review-side scope-creep checks — `code-reviewer.md`, `senior-review`'s code-quality checklist, `small-verifier.md`

**Files:**
- Modify: `plugins/forge/skills/forge/templates/dotclaude/agents/code-reviewer.md`
- Modify: `plugins/forge/skills/forge/templates/dotclaude/skills/senior-review/references/code-quality.md`
- Modify: `plugins/forge/skills/forge/templates/dotclaude/agents/small-verifier.md`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: an explicit, named check that later code-review-consuming workflows (`review-diff.js`, the whole-branch review, `/senior-review`) will now surface scope-creep as a real finding, not just an unenforced hope.

- [ ] **Step 1: Read all three files and confirm they match this plan's assumptions**

```bash
cat plugins/forge/skills/forge/templates/dotclaude/agents/code-reviewer.md
cat plugins/forge/skills/forge/templates/dotclaude/skills/senior-review/references/code-quality.md
cat plugins/forge/skills/forge/templates/dotclaude/agents/small-verifier.md
```

Confirm: `code-reviewer.md`'s `## Operating principles` section exists and currently ends with the line `- Surgical scope: review only the changed lines and their immediate blast radius, not the whole file.` (this existing line is about the *reviewer's own* investigation scope — a different concept from what Step 2 adds, which is a check on whether the *diff itself* stayed surgical). Confirm `code-quality.md` has exactly 7 numbered categories ending with `7. **Tooling.**`. Confirm `small-verifier.md`'s `diff-matches-intent` aspect currently reads exactly as: `you are given the step's stated intent; read the actual diff; check (a) every change serves the stated intent, (b) nothing unrelated was touched, (c) the done-condition stated in the intent is actually met by this diff.` If any of these don't match, STOP and report NEEDS_CONTEXT for that specific file rather than guessing.

- [ ] **Step 2: Add a scope-creep check to `code-reviewer.md`**

In `plugins/forge/skills/forge/templates/dotclaude/agents/code-reviewer.md`, find the `## Operating principles` section's last bullet:
```
- Surgical scope: review only the changed lines and their immediate blast radius, not the whole file.
```
Add a new bullet immediately after it:
```
- Flag scope creep as a finding: does every changed line trace to the stated task? Note unrelated refactors, formatting-only changes to code the task didn't touch, or style drift from the surrounding code — these are findings, not just correctness bugs.
```

- [ ] **Step 3: Add an 8th category to `code-quality.md`**

In `plugins/forge/skills/forge/templates/dotclaude/skills/senior-review/references/code-quality.md`, change the header line:
```
7 categories.
```
to:
```
8 categories.
```
Then add a new category after category 7 (`**Tooling.**`):
```
8. **Scope discipline.** Changes that don't trace to the stated task — a drive-by refactor of unrelated working code, formatting/style changes to lines the task didn't touch, or dead code removed beyond what this change itself made dead (note it instead of removing it).
```

- [ ] **Step 4: Extend `small-verifier.md`'s `diff-matches-intent` aspect**

In `plugins/forge/skills/forge/templates/dotclaude/agents/small-verifier.md`, find:
```
**diff-matches-intent** — you are given the step's stated intent; read the actual diff; check (a) every change serves the stated intent, (b) nothing unrelated was touched, (c) the done-condition stated in the intent is actually met by this diff.
```
Replace with:
```
**diff-matches-intent** — you are given the step's stated intent; read the actual diff; check (a) every change serves the stated intent, (b) nothing unrelated was touched, (c) the done-condition stated in the intent is actually met by this diff, (d) the diff matches the surrounding code's existing style and doesn't remove pre-existing dead code beyond what this change itself made dead.
```

- [ ] **Step 5: Verify all three files' YAML frontmatter (where applicable) still parses**

```bash
python3 -c "
import re, yaml
for path in [
    'plugins/forge/skills/forge/templates/dotclaude/agents/code-reviewer.md',
    'plugins/forge/skills/forge/templates/dotclaude/agents/small-verifier.md',
]:
    text = open(path).read()
    m = re.match(r'^---\n(.*?)\n---\n', text, re.DOTALL)
    assert m, f'{path}: frontmatter missing or malformed'
    yaml.safe_load(m.group(1))
    print(path, 'OK')
"
grep -c "^[0-9]\." plugins/forge/skills/forge/templates/dotclaude/skills/senior-review/references/code-quality.md
```
Expected: both agent files print `OK`; the grep count for `code-quality.md` is `8` (`senior-review/SKILL.md` has no frontmatter to check — it's a skill file with its own frontmatter format already established elsewhere in this repo, not touched by this task, so skip it).

- [ ] **Step 6: Commit**

```bash
git add plugins/forge/skills/forge/templates/dotclaude/agents/code-reviewer.md \
        plugins/forge/skills/forge/templates/dotclaude/skills/senior-review/references/code-quality.md \
        plugins/forge/skills/forge/templates/dotclaude/agents/small-verifier.md
git commit -m "Review-side scope-creep checks (R12 pt.4): code-reviewer, senior-review, small-verifier

Converts 'hope the implementer stayed surgical' into an active,
named review-time check across the three general-purpose code-quality
review surfaces (deliberately excludes security-reviewer.md and
silent-failure-hunter.md — their job is a different specific concern,
and adding this there would itself be scope creep on their own prompts)."
```

---

### Task 5: Document the multi-surface wiring in `GUIDE.md`

**Files:**
- Modify: `plugins/forge/skills/forge/templates/GUIDE.md`

**Interfaces:**
- Consumes: the file list from Tasks 1-4 (this task only documents, doesn't change behavior).

- [ ] **Step 1: Find GUIDE.md's wiring/seams table**

Run: `grep -n "^| Seam" plugins/forge/skills/forge/templates/GUIDE.md` — this locates the wiring table added for `capability-gate.sh`'s seam (state files read/written across multiple hooks). Read the surrounding section for the exact table structure.

- [ ] **Step 2: Add a row for the coding-discipline enforcement seam**

Add a new row to that table:
```markdown
| Coding discipline (R12) | `rules/coding-discipline.md`, `agents/{small-executor,bug-fixer}.md`, `agents/{code-reviewer,small-verifier}.md`, `skills/senior-review/references/code-quality.md` | Six surfaces carry this by design, not accident — agents run in an isolated context and never see `rules/*.md`, so the rules file alone only reaches the main session. If you touch the wording on one surface, check whether the others need the same update; if you remove a surface, confirm the principle is still enforced somewhere. |
```

- [ ] **Step 3: Verify GUIDE.md still isn't part of the always-loaded budget**

```bash
grep -n "GUIDE.md" plugins/forge/skills/forge/templates/dotclaude/scripts/context-budget.sh
```
Expected: no output (confirms this documentation addition costs nothing against the budget gate — `GUIDE.md` is on-demand content).

- [ ] **Step 4: Commit**

```bash
git add plugins/forge/skills/forge/templates/GUIDE.md
git commit -m "GUIDE.md (R12 pt.5): document the coding-discipline multi-surface wiring seam"
```

---

### Task 6: Mark ROADMAP.md's R12 as done, bump the plugin version, push

**Files:**
- Modify: `ROADMAP.md`
- Modify: `plugins/forge/.claude-plugin/plugin.json`

**Interfaces:**
- Consumes: the full shipped state from Tasks 1-5.

- [ ] **Step 1: Read ROADMAP.md's current R12 section**

Run: `grep -n "^## R12" ROADMAP.md` and read that section in full. If it's materially different from the version this plan was designed against (title ending in `(priority: 3rd)`, a Problem/Correction/What's-new/Proposed-approach structure), STOP and report NEEDS_CONTEXT.

- [ ] **Step 2: Update the section to reflect what actually shipped**

Replace the heading:
```
## R12 — Adopt Karpathy's "Think Before Coding" + "Surgical Changes" as new house rules; explicitly skip the rest (priority: 3rd)
```
with:
```
## R12 — Adopt Karpathy's "Think Before Coding" + "Surgical Changes" as new house rules; explicitly skip the rest — ✅ Done
```

Then, immediately after the existing "**Proposed approach.**" paragraph (before the closing `---`), insert:

```markdown

**What shipped — multi-surface, not single-file.** A first draft added only `rules/coding-discipline.md` — but every agent that actually writes or reviews code in this harness runs in an isolated context and never sees `rules/*.md` (confirmed by reading all six agent files directly), so a rules-file-only design would have reached almost none of the actual code-writing that happens through `elevate.js`'s small-model cascade or the whole-branch review flow. Shipped instead: `rules/coding-discipline.md` for the main session; targeted, gap-precise additions to `small-executor.md` and `bug-fixer.md` (both already covered parts of this — the new content is deliberately just the remaining gap: stating assumptions under genuine ambiguity, extending `small-executor.md`'s existing proven Stop hook rather than inventing a new mechanism); an explicit scope-creep check added to `code-reviewer.md`, `senior-review`'s code-quality checklist, and `small-verifier.md`'s `diff-matches-intent` aspect — deliberately *not* added to `security-reviewer.md`/`silent-failure-hunter.md`, whose job is a different specific concern. Always-loaded budget after the rules-file half: 1335 tokens (NEAR LIMIT, target ≤1200, hard cap ≤1500) — the agent-file additions cost nothing against that gate (verified: `context-budget.sh` only globs `CLAUDE.md` + `rules/*.md`).
```

- [ ] **Step 3: Verify the markdown structure is still intact**

Run: `grep -c "^## R" ROADMAP.md`
Expected: `13` (unchanged).

- [ ] **Step 4: Bump the plugin version**

```bash
python3 -c "
import json
d = json.load(open('plugins/forge/.claude-plugin/plugin.json'))
print('current version:', d['version'])
"
```
Then (adjust the target below if the printed current version wasn't `1.5.1`):
```bash
python3 -c "
import json
p = 'plugins/forge/.claude-plugin/plugin.json'
d = json.load(open(p))
d['version'] = '1.5.2'
json.dump(d, open(p, 'w'), indent=2)
print('bumped to', d['version'])
"
```

- [ ] **Step 5: Final fresh-install verification at the bumped version**

```bash
rm -rf /tmp/r12-final
mkdir -p /tmp/r12-final
bash plugins/forge/skills/forge/scripts/bootstrap.sh --target /tmp/r12-final \
  --set PROJECT_NAME=F --set PROJECT_DESC=d --set BUILD_CMD=b --set TEST_CMD=t --set LINT_CMD=l --set FMT_CMD=f > /dev/null 2>&1
bash plugins/forge/skills/forge/scripts/validate.sh --target /tmp/r12-final
ls /tmp/r12-final/.claude/agents/small-executor.md /tmp/r12-final/.claude/agents/bug-fixer.md \
   /tmp/r12-final/.claude/agents/code-reviewer.md /tmp/r12-final/.claude/agents/small-verifier.md \
   /tmp/r12-final/.claude/rules/coding-discipline.md \
   /tmp/r12-final/.claude/skills/senior-review/references/code-quality.md
grep -c "assumption" /tmp/r12-final/.claude/agents/small-executor.md /tmp/r12-final/.claude/agents/bug-fixer.md
python3 -c "import json; print(json.load(open('/tmp/r12-final/.claude/forge-manifest.json'))['forge_version'])"
rm -rf /tmp/r12-final
```
Expected: `VALIDATE: all checks passed`; all 6 files listed exist (no "No such file" errors); the `grep -c "assumption"` counts are both ≥1 (confirms the new content actually installs, not just exists in the template source); the printed version matches Step 4's bump.

- [ ] **Step 6: Commit and push**

```bash
git add ROADMAP.md plugins/forge/.claude-plugin/plugin.json
git commit -m "forge 1.5.2: R12 done — coding-discipline shipped across 6 surfaces, not 1

Mirrors how R1/R10 were marked done in ROADMAP.md: what shipped and
why the design changed from the original single-file draft, not just
a checkmark."
git push origin master
```

---

## Final verification (after all six tasks)

- [ ] `git log --oneline -8` — confirm 6 new commits (Tasks 1-6) exist on top of the previous HEAD, each a separate, independently-reviewable change.
- [ ] `git status --short` — clean working tree.
- [ ] `git rev-list --left-right --count origin/master...master` — `0 0` (fully pushed).
- [ ] Spot-check: `grep -c "assumption" plugins/forge/skills/forge/templates/dotclaude/agents/small-executor.md` and the same for `bug-fixer.md` — both ≥1, confirming the actual template source (not just a fresh install copy) carries the change.
