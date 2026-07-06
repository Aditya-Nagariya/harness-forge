#!/usr/bin/env bash
# PostToolUseFailure hook: append a structured record of every tool failure to
# .claude/state/failure-ledger.jsonl (machine-local, gitignored).
#
# This is the raw-signal half of the self-healing loop: session-start.sh
# aggregates the ledger and surfaces failure signatures that repeat, and the
# /learn skill converts repeated signatures into durable lesson files in
# .claude/memory/lessons/. Silent on success — logging a failure should not
# itself add noise to the conversation.
set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LEDGER="$PROJECT_ROOT/.claude/state/failure-ledger.jsonl"

INPUT="$(cat)"

if ! command -v python3 >/dev/null 2>&1; then
  exit 0
fi

python3 - "$INPUT" "$LEDGER" <<'PY'
import json, sys, os, re, hashlib
from datetime import datetime, timezone

try:
    data = json.loads(sys.argv[1])
except Exception:
    sys.exit(0)

ledger = sys.argv[2]
tool = data.get("tool_name", "") or "unknown"
# Official PostToolUseFailure schema uses "tool_error"; accept legacy "error" too.
error = str(data.get("tool_error", "") or data.get("error", "") or "")

# Normalize the error into a stable signature so the same class of failure
# groups together: strip absolute paths, hex ids, numbers, whitespace runs.
sig_src = error[:400]
sig_src = re.sub(r"/[^\s'\"]+", "<path>", sig_src)
sig_src = re.sub(r"0x[0-9a-fA-F]+|[0-9a-f]{7,}", "<hex>", sig_src)
sig_src = re.sub(r"\d+", "<n>", sig_src)
sig_src = re.sub(r"\s+", " ", sig_src).strip().lower()
signature = hashlib.sha256(f"{tool}|{sig_src}".encode()).hexdigest()[:12]

record = {
    "ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "tool": tool,
    "signature": signature,
    "sig_text": sig_src[:160],
    "error_head": error[:200],
    "session_id": data.get("session_id", ""),
}

# HARNESS_FAILURE_DRYRUN=1 prints the record instead of appending — used by the
# hook test fixtures (same pattern as notify.sh's CLIORCH_NOTIFY_DRYRUN).
if os.environ.get("HARNESS_FAILURE_DRYRUN") == "1":
    print("DRYRUN ledger: " + json.dumps(record, ensure_ascii=False))
    sys.exit(0)

os.makedirs(os.path.dirname(ledger), exist_ok=True)
with open(ledger, "a", encoding="utf-8") as f:
    f.write(json.dumps(record, ensure_ascii=False) + "\n")
PY

exit 0
