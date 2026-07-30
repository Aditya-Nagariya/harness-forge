# Coding Discipline House Rules (R12) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship ROADMAP.md's R12 as real, installed harness content — add exactly two new house-rule principles ("Think before coding," "Surgical changes") to every project `/forge` installs, and nothing else from the source repo, since the other two principles duplicate coverage this harness or Claude Code's own base prompt already has.

**Architecture:** A new `rules/coding-discipline.md` template file (installed into every forged project's `.claude/rules/`), pointed to from `CLAUDE.md.tmpl`'s existing Rules bullet. `rules/git-workflow.md` loses its "Safety (hook-enforced, restated)" section, which was found to be pure duplication of `rules/safety.md` while researching R12 — removing it partially offsets the new file's cost against this harness's own always-loaded context budget.

**Tech Stack:** Plain markdown template files (no code, no hooks, no tests in the fixture/regression sense — the only "test" is the context-budget measurement and the existing `validate.sh`/`self-check.sh` invariant suite).

## Global Constraints

- Do not bulk-import the source repo's `CLAUDE.md` (`multica-ai/andrej-karpathy-skills`). Add only "Think before coding" and "Surgical changes," written in this harness's own voice — not copy-pasted. "Simplicity First" and "Goal-Driven Execution" are explicitly out of scope for this plan (already covered elsewhere — see ROADMAP.md's R12 write-up for the exact citations).
- The always-loaded context budget (measured by `.claude/scripts/context-budget.sh`: `CLAUDE.md` + every unscoped `rules/*.md`) currently sits at 1202 tokens on a fresh install with a typical `PROJECT_DESC` — already "NEAR LIMIT" (target ≤1200, hard cap ≤1500) before this change. The exact final content in Task 1 below was already measured by hand against this same formula and lands at **1335 tokens total (NEAR LIMIT, well under the 1500 hard cap)** — this is the expected, accepted outcome; do not silently claim "PASS" if the real run reports NEAR LIMIT, and do not gut `ship-verification.md`'s content to force a lower number (its closing rationale sentence explains a non-obvious WHY, which this harness's own documented commenting philosophy protects — see the reasoning trail in this plan's file if questioned).
- `rules/*.md` files in this harness carry no YAML frontmatter (confirmed: `safety.md`, `ship-verification.md`, `git-workflow.md` are all plain `# Title` + prose/bullets) — do not add any to the new file.
- Every new rules file needs a pointer from `CLAUDE.md.tmpl`'s existing "Rules" bullet — per that file's own house rule: "Adding a new skill/agent/hook? Add a pointer here... before starting the work — a component nothing points to gets rediscovered from scratch every future session." (This applies to rules files too, by the same logic.)

---

### Task 1: Add `coding-discipline.md`, trim `git-workflow.md`, wire the pointer, verify the budget

**Files:**
- Create: `plugins/forge/skills/forge/templates/dotclaude/rules/coding-discipline.md`
- Modify: `plugins/forge/skills/forge/templates/dotclaude/rules/git-workflow.md`
- Modify: `plugins/forge/skills/forge/templates/CLAUDE.md.tmpl`

**Interfaces:**
- Produces: `.claude/rules/coding-discipline.md` in every forged project (installed by the existing `bootstrap.sh` template-copy loop — no bootstrap.sh changes needed, it already walks every file under `templates/dotclaude/`).
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
Expected: `192` (or very close — a few tokens either way from whitespace is fine; if it's off by more than ~10, re-check you copied the content verbatim from Step 1, don't paraphrase it).

- [ ] **Step 3: Trim `git-workflow.md`'s redundant Safety section**

Read the current file first (`plugins/forge/skills/forge/templates/dotclaude/rules/git-workflow.md`) to confirm it still matches what this plan assumes — it should have a `## Safety (hook-enforced, restated)` section between `## Commit messages` and `## Worktrees`. Replace the entire file with this exact content (the Safety section is removed; nothing else changes):

```markdown
# Git workflow

## Branch naming

`feature/{name}` · `fix/{name}` · `refactor/{name}` · `chore/{name}`. Reference a `TASKS.md` ID in the branch/commit body where useful.

## Commit messages

Conventional Commits: `{type}({scope}): {description}`, types `feat|fix|refactor|docs|test|chore`.

## Worktrees

For parallel/risky work where one line of work shouldn't destabilize another: `claude --worktree <name>` or the `EnterWorktree` tool instead of stashing; code-writing subagents can carry `isolation: worktree`. Full guidance in `.claude/GUIDE.md`.
```

If the file you read does NOT have a `## Safety (hook-enforced, restated)` section (i.e., it's already been trimmed, or the content genuinely differs from what this plan assumes), STOP and report NEEDS_CONTEXT rather than guessing — the removed section's content (force-push/reset-hard/clean-f warnings) is fully covered by `rules/safety.md`, which is why it's safe to remove here, but that reasoning depends on `safety.md` still covering it; don't remove this section if you can't confirm that.

- [ ] **Step 4: Add the pointer in `CLAUDE.md.tmpl`**

In `plugins/forge/skills/forge/templates/CLAUDE.md.tmpl`, find this exact line (under `## Pointers`):
```
- **Rules** (`.claude/rules/`): `safety.md`, `ship-verification.md`, `git-workflow.md`.
```
Replace it with:
```
- **Rules** (`.claude/rules/`): `safety.md`, `ship-verification.md`, `git-workflow.md`, `coding-discipline.md`.
```

- [ ] **Step 5: Verify the full budget, end to end, on a fresh install**

Run:
```bash
rm -rf /tmp/r12-verify
mkdir -p /tmp/r12-verify
bash plugins/forge/skills/forge/scripts/bootstrap.sh --target /tmp/r12-verify \
  --set PROJECT_NAME=R12Verify --set PROJECT_DESC="a reasonably typical one-line project description" \
  --set BUILD_CMD=b --set TEST_CMD=t --set LINT_CMD=l --set FMT_CMD=f > /tmp/r12-bootstrap.log 2>&1
tail -5 /tmp/r12-bootstrap.log
bash /tmp/r12-verify/.claude/scripts/context-budget.sh
```
Expected: the output lists 5 files (`CLAUDE.md`, `coding-discipline.md`, `ship-verification.md`, `safety.md`, `git-workflow.md`) and a total around **1335 tokens** (±10 is fine depending on the exact `PROJECT_DESC` length used above), with `VERDICT: NEAR LIMIT (...)`. This is the expected, accepted result — do not treat it as a failure and do not attempt further cuts; report the real number.

- [ ] **Step 6: Run the full invariant suite to confirm nothing else broke**

Run:
```bash
bash plugins/forge/skills/forge/scripts/validate.sh --target /tmp/r12-verify
bash /tmp/r12-verify/.claude/scripts/self-check.sh
```
Expected: both end with all-pass summaries (`VALIDATE: all checks passed`, `SELF-CHECK: all invariants pass`) — `context budget` will show as `ok` even though its own verdict is NEAR LIMIT, since `self-check.sh` treats NEAR LIMIT as passing (only OVER BUDGET fails it). Hook fixtures and regressions counts should match whatever this repo's current HEAD reports (this task touches no hooks/regressions, so those counts should be unchanged from before this task started — if you're unsure what "before" was, run the same two commands against a fresh install from the current committed HEAD, before your Step 1-4 edits, and diff the two).

- [ ] **Step 7: Clean up the scratch verification directory and commit**

```bash
rm -rf /tmp/r12-verify /tmp/r12-bootstrap.log
git add plugins/forge/skills/forge/templates/dotclaude/rules/coding-discipline.md \
        plugins/forge/skills/forge/templates/dotclaude/rules/git-workflow.md \
        plugins/forge/skills/forge/templates/CLAUDE.md.tmpl
git commit -m "$(cat <<'EOF'
Add rules/coding-discipline.md (R12): Think before coding + Surgical changes

Ships only the two principles from multica-ai/andrej-karpathy-skills that
aren't already covered elsewhere in this harness or Claude Code's own base
prompt (Simplicity First and Goal-Driven Execution both duplicate existing
coverage — see ROADMAP.md's R12 entry for the exact citations). Written in
this harness's own voice, not copy-pasted.

git-workflow.md's "Safety (hook-enforced, restated)" section is removed —
found to be pure duplication of rules/safety.md while researching this,
and removing it partially offsets the new file's context-budget cost.

Always-loaded budget: 1335 tokens (NEAR LIMIT, target <=1200, hard cap
<=1500) on a fresh install with a typical PROJECT_DESC. Accepted as-is —
the new content is non-redundant, and ship-verification.md's rationale
sentence was deliberately kept rather than cut for a lower number.
EOF
)"
```

---

### Task 2: Mark ROADMAP.md's R12 as done, bump the plugin version

**Files:**
- Modify: `ROADMAP.md`
- Modify: `plugins/forge/.claude-plugin/plugin.json`

**Interfaces:**
- Consumes: the shipped state from Task 1 (file names, exact token count) to describe accurately in ROADMAP.md.

- [ ] **Step 1: Read ROADMAP.md's current R12 section**

Run: `grep -n "^## R12" ROADMAP.md` and read that section in full (it runs from that heading to the next `---`). Confirm it still reads as it did when this plan was written (title ending in "(priority: 3rd)", a Problem/Correction/What's-new/Proposed-approach structure) — if it's materially different, stop and report NEEDS_CONTEXT rather than guessing at what changed.

- [ ] **Step 2: Update the section to reflect what shipped**

Replace the R12 heading line:
```
## R12 — Adopt Karpathy's "Think Before Coding" + "Surgical Changes" as new house rules; explicitly skip the rest (priority: 3rd)
```
with:
```
## R12 — Adopt Karpathy's "Think Before Coding" + "Surgical Changes" as new house rules; explicitly skip the rest — ✅ Done
```

Then, immediately after the existing "**Proposed approach.**" paragraph (before the closing `---`), insert a new paragraph:

```markdown

**What shipped.** `rules/coding-discipline.md`, installed into every forged project, pointed to from `CLAUDE.md.tmpl`'s existing Rules bullet. `git-workflow.md`'s redundant "Safety (hook-enforced, restated)" section was removed in the same change (pure duplication of `rules/safety.md`, found while researching this item) to partially offset the new file's context-budget cost. Always-loaded budget after this change: 1335 tokens (NEAR LIMIT, target ≤1200, hard cap ≤1500) on a fresh install — accepted as-is rather than cutting real content (e.g. `ship-verification.md`'s rationale sentence) just to hit a lower number.
```

- [ ] **Step 3: Verify the markdown structure is still intact**

Run: `grep -c "^## R" ROADMAP.md`
Expected: `13` (unchanged — this task edits R12's content, it doesn't add or remove a section).

- [ ] **Step 4: Bump the plugin version**

Read `plugins/forge/.claude-plugin/plugin.json` first to confirm the current version (this plan was written against `1.5.1`; if it's since changed, bump from whatever the actual current value is, one patch version up, not necessarily to `1.5.2`).

```bash
python3 -c "
import json
p = 'plugins/forge/.claude-plugin/plugin.json'
d = json.load(open(p))
print('current version:', d['version'])
"
```

Then bump it (adjust the target version below if the printed current version wasn't `1.5.1`):

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
python3 -c "import json; print(json.load(open('/tmp/r12-final/.claude/forge-manifest.json'))['forge_version'])"
rm -rf /tmp/r12-final
```
Expected: `VALIDATE: all checks passed`, and the printed version matches what Step 4 just set.

- [ ] **Step 6: Commit**

```bash
git add ROADMAP.md plugins/forge/.claude-plugin/plugin.json
git commit -m "forge 1.5.2: R12 done — coding-discipline.md house rules shipped

Mirrors how R1/R10 were marked done in ROADMAP.md: what shipped, and
the accepted context-budget outcome, not just a checkmark."
```

- [ ] **Step 7: Push**

```bash
git push origin master
```

---

## Final verification (after both tasks)

- [ ] Run `git log --oneline -5` and confirm two new commits exist on top of the previous HEAD (the Task 1 content commit, the Task 2 done-marking/version-bump commit).
- [ ] Run `git status --short` and confirm a clean working tree.
- [ ] Run `git rev-list --left-right --count origin/master...master` and confirm `0 0` (fully pushed).
