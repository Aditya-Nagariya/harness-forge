# Autonomous Self-Healing + Capability Awareness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make harness-forge's self-healing loop (`/loop`) actually run without a human remembering to invoke it, and make that trigger reliable by grounding it in a deterministic hook gate rather than an advisory context nudge — closing ROADMAP.md's R1 and R10 together, since R1's reliability was bottlenecked by R10's unsolved problem.

**Architecture:** A new `PreToolUse` hook (`capability-gate.sh`) hard-blocks the first real source-code edit of a session unless (a) `/loop` isn't overdue and (b) a SkillSeek capability search happened this session — with SkillSeek's presence itself optional and fail-open. `/loop` gains a final step that stamps a timestamp file so the gate knows it ran, plus an unattended-mode branch that writes a review summary instead of committing. A new opt-in installer script wires an OS-level scheduler entry (launchd/cron) so `/loop` can also run headless, on its own schedule, with nobody watching.

**Tech Stack:** Bash (hooks, scripts — matches every existing hook in this repo), Python3 (JSON handling within hooks, same pattern as every existing hook), JSON (`settings.json`, state files), the existing `hooks/tests/` fixture+runner harness, the existing `evals/regressions/` runner.

## Global Constraints

- Every new hook follows the existing fail-open-unless-safety-critical convention: `capability-gate.sh` is a new-capability gate, not a security boundary, so it fails **open** (exit 0, no block) if `python3` is missing — matching `bump-updated.sh`/`issue-capture-reminder.sh`, not `protect-files.sh`'s fail-closed.
- `capability-gate.sh`'s `Write|Edit` matcher must never fire on paths under `.claude/` — verified by a dedicated regression check (Task 8). This is the anti-deadlock property: `/loop`'s own first action (`/learn` writing a lesson file) must never itself trip the gate.
- State-file paths inside `capability-gate.sh` must be overridable via env var (`FORGE_STATE_DIR`), the same caller-env-wins-over-harness.env pattern already used for `LOCKFILES` in `protect-files.sh` — this is what lets the hook be tested through the existing shared fixture harness without touching this real repo's own `.claude/state/`.
- The gate uses `permissionDecision: deny`, never `ask` — an `ask` decision requires human confirmation, which would hang forever during an unattended Tier-2 run.
- SkillSeek is a recommended companion, never a bundled/auto-installed dependency. All SkillSeek-aware code must fail open (treat as satisfied / not installed) if SkillSeek's index file is absent.
- Every new template file goes under `plugins/forge/skills/forge/templates/dotclaude/` (installed into a target project's `.claude/`) unless noted otherwise; template placeholders use the existing single-pass `{{KEY}}` substitution.
- Full spec: `docs/superpowers/specs/2026-07-11-autonomous-self-healing-and-capability-awareness-design.md`.

---

### Task 1: `harness.env` — add `LOOP_OVERDUE_HOURS` config key

**Files:**
- Modify: `plugins/forge/skills/forge/templates/dotclaude/harness.env.tmpl`

**Interfaces:**
- Produces: a `LOOP_OVERDUE_HOURS` key later read by `capability-gate.sh` (Task 4) and `session-start.sh` (Task 5).

- [ ] **Step 1: Add the new config line**

Append to the end of `plugins/forge/skills/forge/templates/dotclaude/harness.env.tmpl`:

```bash

# Hours since /loop last ran before capability-gate.sh treats it as overdue
# and blocks the next source edit until /loop runs again (0 = always overdue).
LOOP_OVERDUE_HOURS="24"
```

- [ ] **Step 2: Verify the file is still valid to source**

Run: `bash -c 'source plugins/forge/skills/forge/templates/dotclaude/harness.env.tmpl; echo "$LOOP_OVERDUE_HOURS"'`
Expected: `24`

- [ ] **Step 3: Commit**

```bash
git add plugins/forge/skills/forge/templates/dotclaude/harness.env.tmpl
git commit -m "harness.env: add LOOP_OVERDUE_HOURS for the capability gate"
```

---

### Task 2: `scripts/record-loop-run.sh` — stamp the last-loop-run timestamp

**Files:**
- Create: `plugins/forge/skills/forge/templates/dotclaude/scripts/record-loop-run.sh`
- Test: manual invocation (this is a two-line script with no branching; a fixture is overkill — verified by direct invocation below, consistent with how `gen-dep-graph.sh`-style utility scripts in this repo are handled).

**Interfaces:**
- Produces: `.claude/state/last-loop-run.json` = `{"last_run": "<ISO8601 UTC timestamp>"}`.
- Consumed by: `capability-gate.sh` (Task 4), `session-start.sh` (Task 5).

- [ ] **Step 1: Write the script**

Create `plugins/forge/skills/forge/templates/dotclaude/scripts/record-loop-run.sh`:

```bash
#!/usr/bin/env bash
# Stamps .claude/state/last-loop-run.json with the current UTC timestamp.
# Called as /loop's final step so capability-gate.sh knows the loop ran.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE_FILE="$PROJECT_ROOT/.claude/state/last-loop-run.json"

mkdir -p "$(dirname "$STATE_FILE")"
python3 -c "
import json
from datetime import datetime, timezone
json.dump({'last_run': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}, open('$STATE_FILE', 'w'))
"
echo "recorded loop run at $(python3 -c "import json; print(json.load(open('$STATE_FILE'))['last_run'])")"
```

- [ ] **Step 2: Make it executable and verify it runs**

Run:
```bash
chmod +x plugins/forge/skills/forge/templates/dotclaude/scripts/record-loop-run.sh
mkdir -p /tmp/record-loop-run-test/.claude/state
cp plugins/forge/skills/forge/templates/dotclaude/scripts/record-loop-run.sh /tmp/record-loop-run-test/.claude/scripts.sh 2>/dev/null || true
mkdir -p /tmp/record-loop-run-test/.claude/scripts
cp plugins/forge/skills/forge/templates/dotclaude/scripts/record-loop-run.sh /tmp/record-loop-run-test/.claude/scripts/
bash /tmp/record-loop-run-test/.claude/scripts/record-loop-run.sh
cat /tmp/record-loop-run-test/.claude/state/last-loop-run.json
rm -rf /tmp/record-loop-run-test
```
Expected: prints `recorded loop run at YYYY-MM-DDTHH:MM:SSZ`, and the `cat` shows `{"last_run": "YYYY-MM-DDTHH:MM:SSZ"}` with a timestamp matching (or within a second of) the current time.

- [ ] **Step 3: Commit**

```bash
git add plugins/forge/skills/forge/templates/dotclaude/scripts/record-loop-run.sh
git commit -m "Add record-loop-run.sh: stamps last-loop-run.json for the capability gate"
```

---

### Task 3: `bootstrap.sh` — pre-seed `last-loop-run.json` at fresh install

**Files:**
- Modify: `plugins/forge/skills/forge/scripts/bootstrap.sh`

**Interfaces:**
- Consumes: nothing new.
- Produces: `.claude/state/last-loop-run.json` present immediately after a fresh install, so the gate's "overdue" clock starts at install time instead of reading as "infinitely overdue" (missing file) on the very first edit.

- [ ] **Step 1: Find the fresh-install completion point**

Run: `grep -n 'mode == "upgrade"' plugins/forge/skills/forge/scripts/bootstrap.sh | head -3`

This locates the branch that distinguishes `mode = "new"` from `mode = "upgrade"` (established earlier in this same file — see the `old_hashes`/`mode` assignment near the top of the embedded Python block).

- [ ] **Step 2: Add the seeding step**

Immediately after the manifest is written (find the line `json.dump(manifest, open(manifest_path, "w"), indent=2)` near the end of the embedded Python block), add:

```python
# Fresh installs get a pre-seeded last-loop-run.json so capability-gate.sh's
# overdue clock starts at install time, not "missing file = infinitely overdue."
if mode == "new":
    from datetime import datetime, timezone
    loop_state_path = os.path.join(target, ".claude", "state", "last-loop-run.json")
    os.makedirs(os.path.dirname(loop_state_path), exist_ok=True)
    if not os.path.exists(loop_state_path):
        json.dump(
            {"last_run": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")},
            open(loop_state_path, "w"),
        )
```

- [ ] **Step 3: Verify with a fresh install**

Run:
```bash
rm -rf /tmp/bootstrap-loop-seed-test
mkdir -p /tmp/bootstrap-loop-seed-test
bash plugins/forge/skills/forge/scripts/bootstrap.sh --target /tmp/bootstrap-loop-seed-test \
  --set PROJECT_NAME=T --set PROJECT_DESC=d --set BUILD_CMD=b --set TEST_CMD=t --set LINT_CMD=l --set FMT_CMD=f
cat /tmp/bootstrap-loop-seed-test/.claude/state/last-loop-run.json
rm -rf /tmp/bootstrap-loop-seed-test
```
Expected: `{"last_run": "<today's date>T..."}` printed, no errors.

- [ ] **Step 4: Verify an upgrade does NOT reset it**

Run:
```bash
rm -rf /tmp/bootstrap-loop-seed-test2
mkdir -p /tmp/bootstrap-loop-seed-test2
bash plugins/forge/skills/forge/scripts/bootstrap.sh --target /tmp/bootstrap-loop-seed-test2 \
  --set PROJECT_NAME=T --set PROJECT_DESC=d --set BUILD_CMD=b --set TEST_CMD=t --set LINT_CMD=l --set FMT_CMD=f
echo '{"last_run": "2020-01-01T00:00:00Z"}' > /tmp/bootstrap-loop-seed-test2/.claude/state/last-loop-run.json
bash plugins/forge/skills/forge/scripts/bootstrap.sh --target /tmp/bootstrap-loop-seed-test2 \
  --set PROJECT_NAME=T --set PROJECT_DESC=d --set BUILD_CMD=b --set TEST_CMD=t --set LINT_CMD=l --set FMT_CMD=f
cat /tmp/bootstrap-loop-seed-test2/.claude/state/last-loop-run.json
rm -rf /tmp/bootstrap-loop-seed-test2
```
Expected: still shows `2020-01-01T00:00:00Z` — an upgrade must never touch this user-data timestamp.

- [ ] **Step 5: Commit**

```bash
git add plugins/forge/skills/forge/scripts/bootstrap.sh
git commit -m "bootstrap.sh: pre-seed last-loop-run.json on fresh install only"
```

---

### Task 4: `hooks/capability-gate.sh` — the PreToolUse hard gate

This is the core mechanism. It must exclude `.claude/` paths (anti-deadlock), fail open without `python3`, fail open when SkillSeek isn't installed, and use overridable state-dir/env for testability.

**Files:**
- Create: `plugins/forge/skills/forge/templates/dotclaude/hooks/capability-gate.sh`
- Test: `plugins/forge/skills/forge/templates/dotclaude/hooks/tests/fixtures/capability-gate/01-allows-non-source-path.json`
- Test: `plugins/forge/skills/forge/templates/dotclaude/hooks/tests/fixtures/capability-gate/02-denies-when-loop-overdue.json`
- Test: `plugins/forge/skills/forge/templates/dotclaude/hooks/tests/fixtures/capability-gate/03-allows-when-loop-recent-and-skillseek-absent.json`
- Test: `plugins/forge/skills/forge/templates/dotclaude/hooks/tests/fixtures/capability-gate/04-denies-when-skillseek-present-but-unused.json`
- Test: `plugins/forge/skills/forge/templates/dotclaude/hooks/tests/fixtures/capability-gate/05-allows-once-gate-checked-flag-set.json`

**Interfaces:**
- Consumes: `.claude/state/last-loop-run.json` (Task 2/3), `LOOP_OVERDUE_HOURS` (Task 1), `.claude/state/.skillseek-used-this-session` (set by Task 6), `$HOME/.claude/SKILLS-INDEX.json` (SkillSeek's own default index path — read-only presence check).
- Produces: `.claude/state/.gate-checked-this-session` (marker file), cleared by `session-start.sh` (Task 5).

- [ ] **Step 1: Write the fixtures first (they will fail — no hook script exists yet)**

Create `plugins/forge/skills/forge/templates/dotclaude/hooks/tests/fixtures/capability-gate/01-allows-non-source-path.json`:
```json
{
  "name": "allows edits under .claude/ regardless of overdue state (anti-deadlock)",
  "stdin": { "tool_input": { "file_path": "/repo/.claude/memory/lessons/0009-example.md", "content": "x" } },
  "expect_exit": 0,
  "env": {
    "FORGE_STATE_DIR": "/tmp/capgate-fixture-01-state",
    "LOOP_OVERDUE_HOURS": "24"
  }
}
```

Create `plugins/forge/skills/forge/templates/dotclaude/hooks/tests/fixtures/capability-gate/02-denies-when-loop-overdue.json`:
```json
{
  "name": "denies first source edit when /loop is overdue and gate not yet checked",
  "stdin": { "tool_input": { "file_path": "/repo/src/main.py", "content": "x" } },
  "expect_exit": 2,
  "expect_stdout_contains": ["deny", "/loop"],
  "env": {
    "FORGE_STATE_DIR": "/tmp/capgate-fixture-02-state",
    "LOOP_OVERDUE_HOURS": "24"
  }
}
```

Create `plugins/forge/skills/forge/templates/dotclaude/hooks/tests/fixtures/capability-gate/03-allows-when-loop-recent-and-skillseek-absent.json`:
```json
{
  "name": "allows when /loop ran recently and SkillSeek is not installed (fail-open)",
  "stdin": { "tool_input": { "file_path": "/repo/src/main.py", "content": "x" } },
  "expect_exit": 0,
  "env": {
    "FORGE_STATE_DIR": "/tmp/capgate-fixture-03-state",
    "LOOP_OVERDUE_HOURS": "24",
    "FORGE_SKILLSEEK_INDEX": "/tmp/capgate-fixture-03-state/nonexistent-index.json"
  }
}
```

Create `plugins/forge/skills/forge/templates/dotclaude/hooks/tests/fixtures/capability-gate/04-denies-when-skillseek-present-but-unused.json`:
```json
{
  "name": "denies when /loop is recent but SkillSeek is installed and not yet searched this session",
  "stdin": { "tool_input": { "file_path": "/repo/src/main.py", "content": "x" } },
  "expect_exit": 2,
  "expect_stdout_contains": ["deny", "skill_search"],
  "env": {
    "FORGE_STATE_DIR": "/tmp/capgate-fixture-04-state",
    "LOOP_OVERDUE_HOURS": "24",
    "FORGE_SKILLSEEK_INDEX": "/tmp/capgate-fixture-04-state/present-index.json"
  }
}
```

Create `plugins/forge/skills/forge/templates/dotclaude/hooks/tests/fixtures/capability-gate/05-allows-once-gate-checked-flag-set.json`:
```json
{
  "name": "allows immediately once .gate-checked-this-session is already set",
  "stdin": { "tool_input": { "file_path": "/repo/src/main.py", "content": "x" } },
  "expect_exit": 0,
  "env": {
    "FORGE_STATE_DIR": "/tmp/capgate-fixture-05-state",
    "LOOP_OVERDUE_HOURS": "24"
  }
}
```

Fixtures 02–05 each need their `FORGE_STATE_DIR` pre-populated with specific prior state before the runner executes them (a fresh-loop timestamp for 03/04/05, a pre-set gate-checked flag for 05, a present index file for 04). The shared runner (`hooks/tests/run-all.sh`) only sets env vars and pipes stdin — it doesn't stage files. Extend it minimally:

- [ ] **Step 2: Extend `run-all.sh` to stage fixture-specific state files**

Modify `plugins/forge/skills/forge/templates/dotclaude/hooks/tests/run-all.sh`. Find the loop `for fixture in "$hook_dir"*.json; do` and, immediately after `env_args+=(...)` array is built (before the `printf '%s' "$stdin_json" | env ...` line), add a small staging step driven by an optional `"stage"` key in the fixture (an object of relative-path → file-content pairs, resolved against `FORGE_STATE_DIR` from the fixture's own `env` block):

```bash
    stage_dir=""
    for kv in "${env_args[@]}"; do
      case "$kv" in
        FORGE_STATE_DIR=*) stage_dir="${kv#FORGE_STATE_DIR=}" ;;
      esac
    done
    if [ -n "$stage_dir" ]; then
      rm -rf "$stage_dir"
      mkdir -p "$stage_dir"
      while IFS='=' read -r rel_path content; do
        [ -z "$rel_path" ] && continue
        full_path="$stage_dir/$rel_path"
        mkdir -p "$(dirname "$full_path")"
        printf '%s' "$content" > "$full_path"
      done < <(jq -r '.stage // {} | to_entries[] | "\(.key)=\(.value)"' "$fixture")
    fi
```

- [ ] **Step 3: Add the `stage` blocks to fixtures 02–05**

Update fixture `02-denies-when-loop-overdue.json` — no stage needed (missing `last-loop-run.json` reads as overdue by design), leave as-is.

Update `03-allows-when-loop-recent-and-skillseek-absent.json`, add a `"stage"` key (insert after `"env"`, keep JSON valid — full file):
```json
{
  "name": "allows when /loop ran recently and SkillSeek is not installed (fail-open)",
  "stdin": { "tool_input": { "file_path": "/repo/src/main.py", "content": "x" } },
  "expect_exit": 0,
  "env": {
    "FORGE_STATE_DIR": "/tmp/capgate-fixture-03-state",
    "LOOP_OVERDUE_HOURS": "24",
    "FORGE_SKILLSEEK_INDEX": "/tmp/capgate-fixture-03-state/nonexistent-index.json"
  },
  "stage": {
    "last-loop-run.json": "{\"last_run\": \"2099-01-01T00:00:00Z\"}"
  }
}
```
(2099 stands in for "just ran" in a fixture that has no access to `date`; the hook computes hours-since as `now - last_run`, so a future timestamp always reads as zero-hours-overdue — equivalent to "just ran" for this test's purpose.)

Update `04-denies-when-skillseek-present-but-unused.json`, full file:
```json
{
  "name": "denies when /loop is recent but SkillSeek is installed and not yet searched this session",
  "stdin": { "tool_input": { "file_path": "/repo/src/main.py", "content": "x" } },
  "expect_exit": 2,
  "expect_stdout_contains": ["deny", "skill_search"],
  "env": {
    "FORGE_STATE_DIR": "/tmp/capgate-fixture-04-state",
    "LOOP_OVERDUE_HOURS": "24",
    "FORGE_SKILLSEEK_INDEX": "/tmp/capgate-fixture-04-state/present-index.json"
  },
  "stage": {
    "last-loop-run.json": "{\"last_run\": \"2099-01-01T00:00:00Z\"}",
    "present-index.json": "{}"
  }
}
```

Update `05-allows-once-gate-checked-flag-set.json`, full file:
```json
{
  "name": "allows immediately once .gate-checked-this-session is already set",
  "stdin": { "tool_input": { "file_path": "/repo/src/main.py", "content": "x" } },
  "expect_exit": 0,
  "env": {
    "FORGE_STATE_DIR": "/tmp/capgate-fixture-05-state",
    "LOOP_OVERDUE_HOURS": "24"
  },
  "stage": {
    ".gate-checked-this-session": ""
  }
}
```

- [ ] **Step 4: Run the tests to verify they fail (no hook script exists yet)**

Run: `bash plugins/forge/skills/forge/templates/dotclaude/hooks/tests/run-all.sh 2>&1 | grep capability-gate`
Expected: `SKIP: no hook script found for fixtures/capability-gate (expected .../hooks/capability-gate.sh)` for each of the 5 fixtures.

- [ ] **Step 5: Write the hook script**

Create `plugins/forge/skills/forge/templates/dotclaude/hooks/capability-gate.sh`:

```bash
#!/usr/bin/env bash
# PreToolUse (Write|Edit) hook: hard-gates the first real source-code edit of a
# session behind two conditions — (a) /loop is not overdue, (b) a SkillSeek
# capability search happened this session (or SkillSeek isn't installed, in
# which case this condition is treated as satisfied — fail open on an optional
# companion tool). This is the deterministic replacement for an advisory
# "please run /loop" nudge: hooks get ~100% compliance, prose nudges don't.
#
# Never gates paths under .claude/ — /loop's own first action (/learn writing a
# lesson file) must never trip this gate before /loop can satisfy it. Fails
# open (exit 0) if python3 is missing: this is a capability-quality gate, not a
# security boundary, so a missing interpreter should not block all editing.
set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Caller env wins over harness.env (deterministic fixtures); harness.env wins over defaults.
_PRE_STATE_DIR="${FORGE_STATE_DIR:-}"
_PRE_OVERDUE="${LOOP_OVERDUE_HOURS:-}"
_PRE_SKILLSEEK_INDEX="${FORGE_SKILLSEEK_INDEX:-}"
[ -f "$PROJECT_ROOT/.claude/harness.env" ] && . "$PROJECT_ROOT/.claude/harness.env"
STATE_DIR="${_PRE_STATE_DIR:-$PROJECT_ROOT/.claude/state}"
LOOP_OVERDUE_HOURS="${_PRE_OVERDUE:-${LOOP_OVERDUE_HOURS:-24}}"
SKILLSEEK_INDEX="${_PRE_SKILLSEEK_INDEX:-$HOME/.claude/SKILLS-INDEX.json}"

if ! command -v python3 >/dev/null 2>&1; then
  exit 0
fi

INPUT="$(cat)"
FILE_PATH="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d.get('tool_input',{}).get('file_path',''))" "$INPUT" 2>/dev/null || echo "")"
[ -n "$FILE_PATH" ] || exit 0

# Anti-deadlock: never gate anything under .claude/ (memory, tasks, state, hooks...).
case "$FILE_PATH" in
  */.claude/*) exit 0 ;;
esac

GATE_FLAG="$STATE_DIR/.gate-checked-this-session"
if [ -f "$GATE_FLAG" ]; then
  exit 0
fi

SEARCH_FLAG="$STATE_DIR/.skillseek-used-this-session"
LAST_LOOP_FILE="$STATE_DIR/last-loop-run.json"

loop_overdue="true"
if [ -f "$LAST_LOOP_FILE" ]; then
  loop_overdue="$(python3 -c "
import json, sys
from datetime import datetime, timezone
try:
    last = json.load(open(sys.argv[1]))['last_run']
    last_dt = datetime.strptime(last, '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc)
    hours = (datetime.now(timezone.utc) - last_dt).total_seconds() / 3600
    print('true' if hours > float(sys.argv[2]) else 'false')
except Exception:
    print('true')
" "$LAST_LOOP_FILE" "$LOOP_OVERDUE_HOURS" 2>/dev/null || echo "true")"
fi

skillseek_installed="false"
[ -f "$SKILLSEEK_INDEX" ] && skillseek_installed="true"

skillseek_satisfied="true"
if [ "$skillseek_installed" = "true" ] && [ ! -f "$SEARCH_FLAG" ]; then
  skillseek_satisfied="false"
fi

if [ "$loop_overdue" = "false" ] && [ "$skillseek_satisfied" = "true" ]; then
  mkdir -p "$STATE_DIR"
  touch "$GATE_FLAG"
  exit 0
fi

reasons=()
[ "$loop_overdue" = "true" ] && reasons+=("run /loop first (self-healing maintenance is overdue)")
[ "$skillseek_satisfied" = "false" ] && reasons+=("call the skill_search MCP tool first (SkillSeek is installed but hasn't been used this session — you may be missing a relevant installed skill)")

reason_text="$(IFS='; '; echo "${reasons[*]}")"
python3 -c "
import json, sys
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'permissionDecision': 'deny', 'permissionDecisionReason': sys.argv[1]}}))
" "Before editing source, $reason_text. This check runs once per session; it will not block again after you resolve it." 2>/dev/null || echo "BLOCKED: $reason_text" >&2
exit 2
```

- [ ] **Step 6: Make it executable, run the tests, verify they pass**

Run:
```bash
chmod +x plugins/forge/skills/forge/templates/dotclaude/hooks/capability-gate.sh
bash plugins/forge/skills/forge/templates/dotclaude/hooks/tests/run-all.sh 2>&1 | grep -A1 capability-gate
```
Expected: all 5 `capability-gate` fixtures show `PASS`, final summary line includes them in the passed count with 0 failed.

- [ ] **Step 7: Commit**

```bash
git add plugins/forge/skills/forge/templates/dotclaude/hooks/capability-gate.sh \
        plugins/forge/skills/forge/templates/dotclaude/hooks/tests/fixtures/capability-gate/ \
        plugins/forge/skills/forge/templates/dotclaude/hooks/tests/run-all.sh
git commit -m "Add capability-gate.sh: hard-gates source edits behind /loop-overdue + SkillSeek-search checks"
```

---

### Task 5: `session-start.sh` — clear session flags, surface unattended-run summary

**Files:**
- Modify: `plugins/forge/skills/forge/templates/dotclaude/hooks/session-start.sh`

**Interfaces:**
- Consumes: `.claude/state/unattended-runs/*.md` (written by Task 7's `/loop` extension).
- Produces: clears `.claude/state/.gate-checked-this-session` and `.claude/state/.skillseek-used-this-session` (read by Task 4's gate).

- [ ] **Step 1: Add the flag-clearing step**

In `plugins/forge/skills/forge/templates/dotclaude/hooks/session-start.sh`, immediately after the existing `STATUS_FILE=` / `TASKS_FILE=` variable block near the top, add:

```bash
# Clear per-session capability-gate flags so a new session re-checks both
# conditions (/loop overdue, SkillSeek search used) exactly once.
rm -f "$PROJECT_ROOT/.claude/state/.gate-checked-this-session" \
      "$PROJECT_ROOT/.claude/state/.skillseek-used-this-session"
```

- [ ] **Step 2: Add the unattended-run summary surface**

Find the existing block that builds `git_summary`/`branch` (search for `git_summary="$(git status`). Immediately after it, add:

```bash
unattended_summary=""
UNATTENDED_DIR="$PROJECT_ROOT/.claude/state/unattended-runs"
if [ -d "$UNATTENDED_DIR" ]; then
  pending_count="$(find "$UNATTENDED_DIR" -name '*-summary.md' 2>/dev/null | wc -l | tr -d ' ')"
  if [ "${pending_count:-0}" -gt 0 ]; then
    unattended_summary="$pending_count unattended /loop run(s) awaiting review in .claude/state/unattended-runs/ — read each *-summary.md and decide whether to commit its (currently uncommitted) work."
  fi
fi
```

Then find where the final `additionalContext` JSON is assembled (search for `additionalContext` near the bottom of the file) and add `unattended_summary` into that assembled text, on its own line, only when non-empty (follow the existing pattern used there for `drift_line`, which is also conditionally appended).

- [ ] **Step 3: Verify manually in a scratch directory**

Run:
```bash
rm -rf /tmp/session-start-flag-test
mkdir -p /tmp/session-start-flag-test/.claude/state/unattended-runs
touch /tmp/session-start-flag-test/.claude/state/.gate-checked-this-session
touch /tmp/session-start-flag-test/.claude/state/.skillseek-used-this-session
echo "test summary" > /tmp/session-start-flag-test/.claude/state/unattended-runs/2026-07-11T00-00-00-summary.md
mkdir -p /tmp/session-start-flag-test/.claude/hooks
cp plugins/forge/skills/forge/templates/dotclaude/hooks/session-start.sh /tmp/session-start-flag-test/.claude/hooks/
cd /tmp/session-start-flag-test && bash .claude/hooks/session-start.sh
ls .claude/state/.gate-checked-this-session .claude/state/.skillseek-used-this-session 2>&1
cd - && rm -rf /tmp/session-start-flag-test
```
Expected: the hook's JSON output (printed to stdout) contains the string `unattended /loop run(s) awaiting review`, and the `ls` after running shows both flag files **no longer exist** (`No such file or directory` for both).

- [ ] **Step 4: Commit**

```bash
git add plugins/forge/skills/forge/templates/dotclaude/hooks/session-start.sh
git commit -m "session-start.sh: clear capability-gate session flags, surface unattended-run summary"
```

---

### Task 6: `settings.json` — wire the gate + the SkillSeek-search flag setter

**Files:**
- Modify: `plugins/forge/skills/forge/templates/dotclaude/settings.json`

**Interfaces:**
- Consumes: `capability-gate.sh` (Task 4).
- Produces: the `PostToolUse` entry that touches `.skillseek-used-this-session` when SkillSeek's MCP tool is called.

- [ ] **Step 1: Verify the actual registered tool name before wiring the matcher**

This plan infers SkillSeek's MCP tool is exposed to Claude Code as `mcp__skillseek__skill_search`, based on this session's own observed naming convention (`mcp__<server>__<tool>`, e.g. `mcp__claude_ai_Craft__craft_read`) — **this has not been directly confirmed against SkillSeek's own `.mcp.json`.** Before wiring the matcher, install SkillSeek per its README (`/plugin marketplace add https://github.com/TheQmaks/skillseek` then `/plugin install skillseek`) in a scratch Claude Code session and run `/mcp` (or inspect the tool list) to confirm the exact registered name. If it differs from `mcp__skillseek__skill_search`, use the confirmed name in Step 2 instead.

- [ ] **Step 2: Add the PreToolUse gate entry**

In `plugins/forge/skills/forge/templates/dotclaude/settings.json`, find the existing `"PreToolUse"` array's `"Write|Edit"` matcher block (currently containing `protect-files.sh` and `scan-secrets.sh`). Add `capability-gate.sh` as a third entry in that same block's `"hooks"` array (runs alongside the existing two, all under the same `Write|Edit` matcher):

```json
          { "type": "command", "command": "bash .claude/hooks/capability-gate.sh", "timeout": 10 }
```

- [ ] **Step 3: Add the PostToolUse flag-setter entry**

Add a new top-level entry to the `"PostToolUse"` array (a second matcher block, sibling to the existing `"Write|Edit"` one):

```json
      {
        "matcher": "mcp__skillseek__skill_search",
        "hooks": [
          { "type": "command", "command": "touch .claude/state/.skillseek-used-this-session", "timeout": 5 }
        ]
      }
```

(Adjust the matcher string per Step 1's verification if the confirmed tool name differs.)

- [ ] **Step 4: Validate the JSON and re-run the full hook suite**

Run:
```bash
python3 -c "import json; json.load(open('plugins/forge/skills/forge/templates/dotclaude/settings.json'))" && echo "valid JSON"
bash plugins/forge/skills/forge/templates/dotclaude/hooks/tests/run-all.sh 2>&1 | tail -3
```
Expected: `valid JSON`, and `RESULT: N passed, 0 failed` where N is the previous total plus the 5 new capability-gate fixtures.

- [ ] **Step 5: Commit**

```bash
git add plugins/forge/skills/forge/templates/dotclaude/settings.json
git commit -m "settings.json: wire capability-gate.sh and the SkillSeek-search flag setter"
```

---

### Task 7: `loop.md` — record the run, branch on unattended mode

**Files:**
- Modify: `plugins/forge/skills/forge/templates/dotclaude/loop.md`

**Interfaces:**
- Consumes: `scripts/record-loop-run.sh` (Task 2), `$FORGE_UNATTENDED` env var (set by Task 9's wrapper script).
- Produces: `.claude/state/last-loop-run.json` updated on every `/loop` completion; `.claude/state/unattended-runs/<timestamp>-summary.md` when running unattended.

- [ ] **Step 1: Add the final step and the unattended branch**

Replace the full content of `plugins/forge/skills/forge/templates/dotclaude/loop.md` with:

```markdown
# {{PROJECT_NAME}} maintenance loop

You are on a maintenance iteration. Do the highest-value item below, then stop; the loop will bring you back.

1. **Finish in-flight work first.** If `.claude/tasks/TASKS.md` has anything `running`, `broken`, or `needs-fix`, that outranks everything here — resume it.
2. **Convert failure signal into lessons.** If `.claude/state/failure-ledger.jsonl` has signatures with ≥2 occurrences, run `/learn`.
3. **Checkpoint hygiene (only when a milestone/feature just completed and the tree is green).** Run `/context-budget`; if it's NEAR LIMIT or OVER, trim per that skill. Then run `/declutter` to prune dead code / unused deps / orphaned files accumulated during the feature. Skip both mid-feature.
4. **Audit the harness.** If none of the above applies, run `/harness-audit`. Fix mechanical failures it finds; propose (don't apply) judgment-level changes.
5. **Idle case.** If everything is clean and there is no in-flight work, pick the lowest-numbered `pending` task in `TASKS.md` and start it via `/milestone-task`.

Rules: never `--force` anything, never push, never mark a task `completed` without the ship-verification bar, and prefer finishing over starting.

## Unattended mode

If the `$FORGE_UNATTENDED` environment variable is set, nobody is watching this run in real time:

- Skip `/ship`'s commit/push steps entirely, regardless of how confident the change looks. A task reaching `/milestone-task`'s or `/ship`'s commit point stops at "implemented and verified, NOT committed" — an `ask`-style confirmation would hang forever with nobody to answer it.
- As your final action, write `.claude/state/unattended-runs/<UTC timestamp, format YYYY-MM-DDTHH-MM-SSZ>-summary.md` (use `-` not `:` in the time portion — colons are invalid in filenames on some filesystems) containing: what step of the loop ran, what was done, the exact verification commands run and their output, and the working tree's current `git status --short` so the next interactive session can review and decide whether to commit.

## Final step (always, both modes)

Run `bash .claude/scripts/record-loop-run.sh` as your last action, whether or not `$FORGE_UNATTENDED` is set — this is what tells `capability-gate.sh` the loop ran.
```

- [ ] **Step 2: Verify the file still substitutes cleanly**

Run:
```bash
rm -rf /tmp/loop-md-test
mkdir -p /tmp/loop-md-test
bash plugins/forge/skills/forge/scripts/bootstrap.sh --target /tmp/loop-md-test \
  --set PROJECT_NAME=TestProj --set PROJECT_DESC=d --set BUILD_CMD=b --set TEST_CMD=t --set LINT_CMD=l --set FMT_CMD=f
grep -c "TestProj" /tmp/loop-md-test/.claude/loop.md
grep -c "{{" /tmp/loop-md-test/.claude/loop.md
rm -rf /tmp/loop-md-test
```
Expected: first `grep -c` prints `1` (the substituted project name), second prints `0` (no leftover placeholders).

- [ ] **Step 3: Commit**

```bash
git add plugins/forge/skills/forge/templates/dotclaude/loop.md
git commit -m "loop.md: record last-run timestamp; add unattended-mode no-commit branch"
```

---

### Task 8: Regression check — gate never fires on `.claude/` paths

**Files:**
- Create: `plugins/forge/skills/forge/templates/dotclaude/evals/regressions/0004-capability-gate-excludes-dotclaude.sh`

**Interfaces:**
- Consumes: `capability-gate.sh` (Task 4).

- [ ] **Step 1: Write the check**

Create `plugins/forge/skills/forge/templates/dotclaude/evals/regressions/0004-capability-gate-excludes-dotclaude.sh`:

```bash
#!/usr/bin/env bash
# Regression check: capability-gate.sh must NEVER block a Write/Edit under
# .claude/ — otherwise /loop's own first action (/learn writing a lesson file)
# would trip the gate before /loop could ever satisfy it (self-inflicted
# deadlock). Derived from the R1+R10 combined design's anti-deadlock rule.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

HOOK=".claude/hooks/capability-gate.sh"
if [ ! -f "$HOOK" ]; then
  echo "capability-gate.sh not found at $HOOK"
  exit 1
fi

# Force worst-case conditions: loop badly overdue, no gate-checked flag —
# if the exclusion works, none of this should matter for a .claude/ path.
STATE_DIR="$(mktemp -d)"
export FORGE_STATE_DIR="$STATE_DIR"
export LOOP_OVERDUE_HOURS="24"
echo '{"last_run": "2000-01-01T00:00:00Z"}' > "$STATE_DIR/last-loop-run.json"

out="$(echo '{"tool_input":{"file_path":"/repo/.claude/memory/lessons/0009-test.md","content":"x"}}' | bash "$HOOK")"
exit_code=$?
rm -rf "$STATE_DIR"

if [ "$exit_code" != "0" ]; then
  echo "FAIL: capability-gate.sh blocked a .claude/ path (exit $exit_code, output: $out)"
  exit 1
fi
exit 0
```

- [ ] **Step 2: Make it executable, run it standalone, then via the runner**

Run:
```bash
chmod +x plugins/forge/skills/forge/templates/dotclaude/evals/regressions/0004-capability-gate-excludes-dotclaude.sh
bash plugins/forge/skills/forge/templates/dotclaude/evals/regressions/0004-capability-gate-excludes-dotclaude.sh && echo "check passed standalone"
bash plugins/forge/skills/forge/templates/dotclaude/evals/regressions/run-all.sh 2>&1 | tail -5
```
Expected: `check passed standalone`, and the runner's summary shows one more pass than before with 0 failed.

- [ ] **Step 3: Commit**

```bash
git add plugins/forge/skills/forge/templates/dotclaude/evals/regressions/0004-capability-gate-excludes-dotclaude.sh
git commit -m "Add regression check: capability-gate.sh must never fire on .claude/ paths"
```

---

### Task 9: `scripts/setup-unattended-loop.sh` — Tier 2 installer

**Files:**
- Create: `plugins/forge/skills/forge/templates/dotclaude/scripts/setup-unattended-loop.sh`
- Create: `plugins/forge/skills/forge/templates/dotclaude/scripts/unattended-loop-wrapper.sh`

**Interfaces:**
- Produces: on macOS, a launchd plist at `~/Library/LaunchAgents/com.forge.unattended-loop.<project-hash>.plist`, loaded via `launchctl load`; on Linux, a crontab entry via `crontab -l`/`crontab -`. Both invoke `unattended-loop-wrapper.sh`, which sets `FORGE_UNATTENDED=1` and runs `claude -p "/loop"` from the project directory.

- [ ] **Step 1: Write the wrapper script**

Create `plugins/forge/skills/forge/templates/dotclaude/scripts/unattended-loop-wrapper.sh`:

```bash
#!/usr/bin/env bash
# Invoked by the OS scheduler (launchd/cron) — runs /loop headlessly with
# FORGE_UNATTENDED=1 set (loop.md checks this to skip commit/push). Logs to
# .claude/state/unattended-runs/ for later review.
set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

mkdir -p .claude/state/unattended-runs
LOG_FILE=".claude/state/unattended-runs/$(date -u +%Y-%m-%dT%H-%M-%SZ)-run.log"

FORGE_UNATTENDED=1 claude -p "/loop" >"$LOG_FILE" 2>&1
```

- [ ] **Step 2: Write the installer, detecting the platform**

Create `plugins/forge/skills/forge/templates/dotclaude/scripts/setup-unattended-loop.sh`:

```bash
#!/usr/bin/env bash
# Installs (or removes, with --remove) an OS-level scheduler entry that runs
# unattended-loop-wrapper.sh on an interval. macOS: launchd. Linux: cron.
# This is opt-in — /forge only calls this after explicit user confirmation.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WRAPPER="$PROJECT_ROOT/.claude/scripts/unattended-loop-wrapper.sh"
INTERVAL_HOURS="${1:-6}"
ACTION="${2:-install}"

# A stable-per-project identifier so multiple projects don't collide.
if command -v shasum >/dev/null 2>&1; then
  PROJECT_HASH="$(echo -n "$PROJECT_ROOT" | shasum -a 256 | cut -c1-12)"
else
  PROJECT_HASH="$(echo -n "$PROJECT_ROOT" | sha256sum | cut -c1-12)"
fi
LABEL="com.forge.unattended-loop.${PROJECT_HASH}"

if ! command -v claude >/dev/null 2>&1; then
  echo "error: 'claude' CLI not found on PATH — cannot install an unattended loop that invokes it." >&2
  exit 1
fi

os="$(uname -s)"

if [ "$os" = "Darwin" ]; then
  PLIST_PATH="$HOME/Library/LaunchAgents/${LABEL}.plist"
  if [ "$ACTION" = "--remove" ]; then
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
    rm -f "$PLIST_PATH"
    echo "removed launchd entry: $PLIST_PATH"
    exit 0
  fi
  INTERVAL_SECONDS=$((INTERVAL_HOURS * 3600))
  mkdir -p "$(dirname "$PLIST_PATH")"
  cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${WRAPPER}</string>
  </array>
  <key>StartInterval</key><integer>${INTERVAL_SECONDS}</integer>
  <key>RunAtLoad</key><false/>
</dict>
</plist>
EOF
  launchctl unload "$PLIST_PATH" 2>/dev/null || true
  launchctl load "$PLIST_PATH"
  echo "installed launchd entry: $PLIST_PATH (every ${INTERVAL_HOURS}h)"

elif [ "$os" = "Linux" ]; then
  CRON_MARKER="# forge-unattended-loop:${LABEL}"
  if [ "$ACTION" = "--remove" ]; then
    crontab -l 2>/dev/null | grep -vF "$CRON_MARKER" | grep -vF "$WRAPPER" | crontab -
    echo "removed cron entry for $LABEL"
    exit 0
  fi
  CRON_LINE="0 */${INTERVAL_HOURS} * * * /bin/bash ${WRAPPER} ${CRON_MARKER}"
  (crontab -l 2>/dev/null | grep -vF "$CRON_MARKER"; echo "$CRON_LINE") | crontab -
  echo "installed cron entry: every ${INTERVAL_HOURS}h"

else
  echo "error: unattended scheduling is only implemented for macOS (launchd) and Linux (cron). Detected: $os" >&2
  exit 1
fi
```

- [ ] **Step 3: Verify on this machine (macOS/Darwin)**

Run:
```bash
chmod +x plugins/forge/skills/forge/templates/dotclaude/scripts/setup-unattended-loop.sh \
          plugins/forge/skills/forge/templates/dotclaude/scripts/unattended-loop-wrapper.sh
rm -rf /tmp/unattended-loop-test
mkdir -p /tmp/unattended-loop-test/.claude/scripts
cp plugins/forge/skills/forge/templates/dotclaude/scripts/setup-unattended-loop.sh \
   plugins/forge/skills/forge/templates/dotclaude/scripts/unattended-loop-wrapper.sh \
   /tmp/unattended-loop-test/.claude/scripts/
bash /tmp/unattended-loop-test/.claude/scripts/setup-unattended-loop.sh 6 install
PROJECT_HASH="$(echo -n /tmp/unattended-loop-test | shasum -a 256 | cut -c1-12)"
cat "$HOME/Library/LaunchAgents/com.forge.unattended-loop.${PROJECT_HASH}.plist"
bash /tmp/unattended-loop-test/.claude/scripts/setup-unattended-loop.sh 6 --remove
ls "$HOME/Library/LaunchAgents/com.forge.unattended-loop.${PROJECT_HASH}.plist" 2>&1
rm -rf /tmp/unattended-loop-test
```
Expected: the `cat` shows a valid plist with `StartInterval` = `21600` (6×3600); after `--remove`, the final `ls` reports `No such file or directory`.

**Note:** the Linux/cron path is written to the same platform-detection convention but has not been machine-verified here (this reference machine is Darwin) — flag this explicitly during review; a Linux CI job or manual Linux verification should confirm the `crontab` interaction before this is considered fully verified cross-platform.

- [ ] **Step 4: Commit**

```bash
git add plugins/forge/skills/forge/templates/dotclaude/scripts/setup-unattended-loop.sh \
        plugins/forge/skills/forge/templates/dotclaude/scripts/unattended-loop-wrapper.sh
git commit -m "Add setup-unattended-loop.sh: opt-in launchd/cron installer for Tier 2"
```

---

### Task 10: `forge` SKILL.md — opt-in Tier 2 confirmation step

**Files:**
- Modify: `plugins/forge/skills/forge/SKILL.md` (the `/forge` command's own skill file — confirmed via direct read earlier in this session; Step 1 below is a final sanity check only, not a real unknown).

**Interfaces:**
- Consumes: `setup-unattended-loop.sh` (Task 9).

- [ ] **Step 1: Confirm the exact file path**

Run: `find plugins/forge -maxdepth 3 -name "SKILL.md"`
Expected: exactly one match, `plugins/forge/skills/forge/SKILL.md`. Use that path below.

- [ ] **Step 2: Add a new phase after Phase 4 (Verify)**

In `plugins/forge/skills/forge/SKILL.md`, after the existing `### Phase 4 — Verify (mandatory, not optional)` section and before `### Phase 5 — Report`, insert:

```markdown
### Phase 4.5 — Unattended loop (optional, ask first)

Only on a fresh install (not every upgrade): ask the user via AskUserQuestion whether to set up unattended background maintenance — `/loop` running on an OS-level schedule (launchd on macOS, cron on Linux) even when no Claude Code session is open, doing real work but never auto-committing (results land in `.claude/state/unattended-runs/` for review). Default answer if asked generically: recommend yes on a solo/personal project, since it's the only way `/loop` runs when nobody's around to invoke it manually.

If confirmed: ask for an interval in hours (suggest 6 as a default), then run `bash .claude/scripts/setup-unattended-loop.sh <hours> install` and report the result verbatim (which OS mechanism it used, where the entry lives). If declined or the platform isn't macOS/Linux, skip silently — this step is never required.
```

- [ ] **Step 3: Update Phase 5's summary line to mention it**

Find the `### Phase 5 — Report` section's summary line (mentioning `/learn`, `/harness-audit`, `/ship`) and extend it to also note whether unattended scheduling was installed, e.g. append: `, and whether unattended background maintenance is running (Phase 4.5)`.

- [ ] **Step 4: Verify the file's YAML frontmatter and markdown are still well-formed**

Run:
```bash
python3 -c "
import re
text = open('plugins/forge/skills/forge/SKILL.md').read()
m = re.match(r'^---\n(.*?)\n---\n', text, re.DOTALL)
assert m, 'frontmatter missing or malformed'
import yaml
yaml.safe_load(m.group(1))
print('frontmatter OK')
"
```
Expected: `frontmatter OK` (if `yaml` isn't available, `pip install pyyaml` first, or substitute a manual visual check that the `---`-delimited block at the top still has matching `name`/`description`/etc. keys unbroken by the edit).

- [ ] **Step 5: Commit**

```bash
git add "plugins/forge/skills/forge/SKILL.md"
git commit -m "/forge: add opt-in Phase 4.5 offering unattended loop scheduling"
```

---

### Task 11: `GUIDE.md` — document the new gate, state files, and SkillSeek companion

**Files:**
- Modify: `plugins/forge/skills/forge/templates/GUIDE.md`

- [ ] **Step 1: Add to the wiring/seams table**

Find `GUIDE.md`'s wiring table (documents "seams that must stay connected" — referenced in earlier harness-audit work as covering things like the `routing-stats.json` seam). Add a row:

```markdown
| `capability-gate.sh` (PreToolUse) | `.claude/state/last-loop-run.json`, `.claude/state/.skillseek-used-this-session` | `record-loop-run.sh` (called by `loop.md`'s final step) writes the former; the PostToolUse SkillSeek-search matcher in `settings.json` writes the latter. If either writer is ever removed, the gate silently reads stale/missing state — check both still exist before removing either. |
```

- [ ] **Step 2: Add a short paragraph on SkillSeek as a recommended (not bundled) companion**

Near wherever `GUIDE.md` documents optional companion tooling (or, if no such section exists yet, add one near the end under a `## Recommended companions` heading):

```markdown
## Recommended companions

- **[SkillSeek](https://github.com/TheQmaks/skillseek)** — indexes every locally-installed skill (including plugin-bundled ones) for BM25 search, so the model can find a relevant skill instead of missing it under Claude Code's `skillListingBudgetFraction` cap. `capability-gate.sh` checks for its presence and adapts (requires a search before the first source edit if installed; skips that condition entirely if not) — never bundled or auto-installed by `/forge`. Install separately: `/plugin marketplace add https://github.com/TheQmaks/skillseek` then `/plugin install skillseek`.
```

- [ ] **Step 3: Verify context budget still passes**

Run: `bash plugins/forge/skills/forge/templates/dotclaude/scripts/context-budget.sh` (or, if this doesn't apply to `GUIDE.md` directly since it's on-demand content per the existing zone classification, confirm via `grep` that `GUIDE.md` is not one of the files `context-budget.sh` sums — it measures `CLAUDE.md` + unscoped `rules/*.md` only). Run:
```bash
grep -n "GUIDE.md" plugins/forge/skills/forge/templates/dotclaude/scripts/context-budget.sh
```
Expected: no output — confirms `GUIDE.md` is on-demand content, not part of the always-loaded budget, so this addition costs nothing against the budget gate.

- [ ] **Step 4: Commit**

```bash
git add plugins/forge/skills/forge/templates/GUIDE.md
git commit -m "GUIDE.md: document capability-gate.sh's wiring seam and SkillSeek as a recommended companion"
```

---

### Task 12: `README.md` — mention the new capability

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add a row to the "What the forged harness contains" table**

In `README.md`, add a new table row (after the existing "Self-maintenance" row, matching that table's style):

```markdown
| **Autonomous self-healing** | `/loop` no longer needs a human to remember to invoke it: `capability-gate.sh` hard-blocks the first source edit of a session until `/loop` has run recently (default: within 24h) — and, if [SkillSeek](https://github.com/TheQmaks/skillseek) is installed, until a capability search has happened this session too. An opt-in Tier 2 (`/forge`'s Phase 4.5) adds a launchd/cron entry so `/loop` also runs headlessly on a schedule, writing a review summary instead of auto-committing. |
```

- [ ] **Step 2: Verify markdown table syntax renders (visual check)**

Run: `grep -c '^|' README.md` before and after — confirm the count increased by exactly 1 (one new table row added, nothing else broken).

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "README: document the autonomous self-healing capability gate"
```

---

## Final verification (after all 12 tasks)

- [ ] Run the full suite one more time end-to-end:
```bash
rm -rf /tmp/final-r1-r10-verify
mkdir -p /tmp/final-r1-r10-verify
bash plugins/forge/skills/forge/scripts/bootstrap.sh --target /tmp/final-r1-r10-verify \
  --set PROJECT_NAME=FinalVerify --set PROJECT_DESC=d --set BUILD_CMD=b --set TEST_CMD=t --set LINT_CMD=l --set FMT_CMD=f
bash plugins/forge/skills/forge/scripts/validate.sh --target /tmp/final-r1-r10-verify
bash /tmp/final-r1-r10-verify/.claude/scripts/self-check.sh
cat /tmp/final-r1-r10-verify/.claude/state/last-loop-run.json
rm -rf /tmp/final-r1-r10-verify
```
Expected: `VALIDATE: all checks passed`, `SELF-CHECK: all invariants pass`, and a valid `last-loop-run.json` seeded at install time.
- [ ] Bump `plugins/forge/.claude-plugin/plugin.json` version and commit as the final task of this feature (follow the existing version-bump convention from prior batches).
