#!/usr/bin/env bash
# PreToolUse (Write|Edit) hook: regex secret scan on new file content.
# Adapted from dotclaude-main's scan-secrets.sh. Uses "ask" not "deny" — these are
# heuristic patterns that can false-positive on test fixtures, so we warn and let
# the user confirm rather than hard-blocking (content-scanning hook: fails open
# if python3 is missing).
set -uo pipefail

INPUT="$(cat)"

if ! command -v python3 >/dev/null 2>&1; then
  exit 0
fi

CONTENT="$(python3 -c "
import json, sys
d = json.loads(sys.argv[1])
ti = d.get('tool_input', {}) or {}
print(ti.get('content','') or ti.get('new_string','') or '')
" "$INPUT" 2>/dev/null || echo "")"

if [[ -z "$CONTENT" ]]; then
  exit 0
fi

ask() {
  python3 -c "
import json, sys
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'permissionDecision': 'ask', 'permissionDecisionReason': sys.argv[1]}}))
" "$1"
  exit 2
}

# AWS access key
if [[ "$CONTENT" =~ AKIA[0-9A-Z]{16} ]]; then
  ask "Content looks like it contains an AWS access key ID (AKIA...). Confirm this isn't a real credential before proceeding."
fi

# Generic sk- style keys (Anthropic/OpenAI/Stripe etc., incl. hyphenated sk-ant-api03-...)
if [[ "$CONTENT" =~ sk-[a-zA-Z0-9-]{20,} ]]; then
  ask "Content looks like it contains an API secret key (sk-...). Confirm this isn't a real credential before proceeding."
fi

# GitHub tokens
if [[ "$CONTENT" =~ (ghp_|gho_|ghs_|ghr_|github_pat_)[a-zA-Z0-9_]{20,} ]]; then
  ask "Content looks like it contains a GitHub token. Confirm this isn't a real credential before proceeding."
fi

# Private key block
if [[ "$CONTENT" == *"-----BEGIN"*"PRIVATE KEY-----"* ]]; then
  ask "Content contains a PRIVATE KEY block. Confirm this isn't a real key before proceeding."
fi

# Connection string with embedded credentials
if [[ "$CONTENT" =~ (postgres|mysql|mongodb|redis)://[^:[:space:]]+:[^@[:space:]]+@ ]]; then
  ask "Content looks like a connection string with embedded credentials. Confirm before proceeding."
fi

exit 0
