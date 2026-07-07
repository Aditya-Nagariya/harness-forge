#!/usr/bin/env bash
# SessionStart hook: inject current health, open tasks, git state, config drift,
# top lessons, and repeated-failure hotspots as additional context — every session
# starts knowing the project's live state and its own past mistakes.
set -uo pipefail  # not -e: a failed sub-block must not drop all session context

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

[ -f .claude/harness.env ] && . .claude/harness.env
PROJECT_NAME="${PROJECT_NAME:-project}"
FINGERPRINT_FILES="${FINGERPRINT_FILES:-}"

STATUS_FILE=".claude/state/status.json"
TASKS_FILE=".claude/tasks/TASKS.md"

health_summary="status.json not found"
if [ -f "$STATUS_FILE" ] && command -v python3 >/dev/null 2>&1; then
  health_summary="$(python3 - "$STATUS_FILE" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    h = d.get("health", {})
    print(f"build={h.get('build','?')} lint={h.get('lint','?')} tests={h.get('tests','?')} (checked {h.get('last_checked','?')})")
except Exception as e:
    print(f"(could not parse status.json: {e})")
PY
)"
fi

open_tasks="?"
if [ -f "$TASKS_FILE" ]; then
  open_tasks="$(grep -cE '^Status: (pending|running|needs-fix|broken|upgrading)' "$TASKS_FILE" 2>/dev/null)" || open_tasks=0
fi

git_summary="$(git status --short 2>/dev/null | head -10 || echo "(not a git repo or no changes)")"
branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "no-git")"

# --- Config-drift fingerprint: hash the manifest surface; nudge once on change ---
drift_line=""
FINGERPRINT_FILE=".claude/state/.fingerprint.json"
if [ -n "$FINGERPRINT_FILES" ] && command -v python3 >/dev/null 2>&1; then
  drift_line="$(python3 - "$FINGERPRINT_FILE" $FINGERPRINT_FILES <<'PY'
import json, hashlib, os, sys
fp_path = sys.argv[1]
h = hashlib.sha256()
for p in sorted(sys.argv[2:]):
    if os.path.exists(p):
        with open(p, "rb") as f:
            h.update(f.read())
current = h.hexdigest()
prev = None
if os.path.exists(fp_path):
    try:
        prev = json.load(open(fp_path)).get("manifest_hash")
    except Exception:
        prev = None
os.makedirs(os.path.dirname(fp_path), exist_ok=True)
json.dump({"manifest_hash": current}, open(fp_path, "w"))
if prev is not None and prev != current:
    print("- Config drift: project manifest files changed since the fingerprint was last recorded. If the toolchain changed, update .claude/harness.env and re-check CLAUDE.md's commands section.")
PY
)"
fi

# --- Top lessons (k<=3, JIT injection — few high-weight items, never the whole store) ---
lessons_block=""
LESSONS_INDEX=".claude/memory/lessons/INDEX.md"
if [ -f "$LESSONS_INDEX" ] && command -v python3 >/dev/null 2>&1; then
  lessons_block="$(python3 - "$LESSONS_INDEX" <<'PY'
import re, sys
lines = []
for line in open(sys.argv[1], encoding="utf-8"):
    m = re.match(r"^- (\d{4}) \[([\d.]+)\] — (.+)$", line.strip())
    if m:
        lines.append((float(m.group(2)), m.group(1), m.group(3)))
lines.sort(reverse=True)
top = lines[:3]
rest = len(lines) - len(top)
if top:
    out = ["- Top lessons (full store: .claude/memory/lessons/):"]
    for w, lid, summary in top:
        out.append(f"  - [{lid}] {summary}")
    if rest > 0:
        out.append(f"  - (+{rest} more in INDEX.md — consult when a trigger matches)")
    print("\n".join(out))
PY
)"
fi

# --- Failure hotspots: signatures repeating >=2 times deserve a /learn pass ---
hotspots_block=""
LEDGER=".claude/state/failure-ledger.jsonl"
if [ -f "$LEDGER" ] && command -v python3 >/dev/null 2>&1; then
  hotspots_block="$(python3 - "$LEDGER" <<'PY'
import json, sys
from collections import Counter
sigs, texts = Counter(), {}
try:
    with open(sys.argv[1], encoding="utf-8") as f:
        records = [json.loads(l) for l in f if l.strip()][-200:]
except Exception:
    records = []
for r in records:
    s = r.get("signature", "")
    sigs[s] += 1
    texts[s] = r.get("sig_text", "")[:100]
hot = [(c, s) for s, c in sigs.items() if c >= 2]
hot.sort(reverse=True)
if hot:
    out = ["- Repeated tool failures (run /learn to convert into lessons):"]
    for c, s in hot[:3]:
        out.append(f"  - {c}x [{s}] {texts[s]}")
    print("\n".join(out))
PY
)"
fi

context=$(cat <<EOF
$PROJECT_NAME session start summary:
- Health: $health_summary
- Open tasks in .claude/tasks/TASKS.md: $open_tasks (six-status vocabulary: pending/running/needs-fix/broken/upgrading/completed)
- Git branch: $branch
- Working tree changes (first 10 lines):
$git_summary
$drift_line
$lessons_block
$hotspots_block
- Management rules for files/folders/data: .claude/GUIDE.md (read before creating any new file outside src).
EOF
)

python3 - "$context" <<'PY'
import json, sys
print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": sys.argv[1]}}))
PY
