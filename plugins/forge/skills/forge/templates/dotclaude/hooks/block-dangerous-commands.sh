#!/usr/bin/env bash
# PreToolUse (Bash) hook: block genuinely dangerous shell commands.
# Stack-agnostic core; protected dirs/branches come from .claude/harness.env.
# Fails open if the command can't be parsed (content-scanning hook).
set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# Caller env wins over harness.env (keeps test fixtures deterministic regardless
# of per-project config); harness.env wins over the built-in defaults.
_PRE_PD="${PROTECTED_DIRS:-}"
_PRE_PB="${PROTECTED_BRANCHES:-}"
[ -f "$PROJECT_ROOT/.claude/harness.env" ] && . "$PROJECT_ROOT/.claude/harness.env"
PROTECTED_DIRS="${_PRE_PD:-${PROTECTED_DIRS:-src}}"
PROTECTED_BRANCHES="${_PRE_PB:-${PROTECTED_BRANCHES:-main,master}}"

INPUT="$(cat)"

if ! command -v python3 >/dev/null 2>&1; then
  exit 0
fi

COMMAND="$(python3 -c "
import json, sys
d = json.loads(sys.argv[1])
print(d.get('tool_input', {}).get('command', '') or '')
" "$INPUT" 2>/dev/null || echo "")"

if [[ -z "$COMMAND" ]]; then
  exit 0
fi

deny() {
  python3 -c "
import json, sys
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'permissionDecision': 'deny', 'permissionDecisionReason': sys.argv[1]}}))
" "$1"
  exit 2
}

BR_REGEX="$(printf '%s' "$PROTECTED_BRANCHES" | tr ',' '|')"

# --- git: force push (allow --force-with-lease) ---
if [[ "$COMMAND" =~ git[[:space:]]+push ]] && [[ "$COMMAND" =~ (-[a-zA-Z]*f[a-zA-Z]*|--force)([[:space:]=]|$) ]] && [[ "$COMMAND" != *"--force-with-lease"* ]]; then
  deny "Force push is blocked (use --force-with-lease if you truly need it, and confirm with the user first)."
fi

# --- git: push directly to a protected branch ---
if [[ "$COMMAND" =~ git[[:space:]]+push ]] && [[ "$COMMAND" =~ ($BR_REGEX)($|[[:space:]]) ]]; then
  deny "Push targets a protected branch ($PROTECTED_BRANCHES). Confirm with the user before pushing directly to it."
fi

# --- git: reset --hard / clean -f ---
if [[ "$COMMAND" =~ git[[:space:]]+reset[[:space:]]+--hard ]]; then
  deny "git reset --hard discards uncommitted work irreversibly. Confirm with the user first."
fi
if [[ "$COMMAND" =~ git[[:space:]]+clean[[:space:]]+-[a-zA-Z]*f ]]; then
  deny "git clean -f deletes untracked files irreversibly. Confirm with the user first."
fi

# --- rm -rf: strip quotes first so quoted/expanded paths are still caught ---
STRIPPED="$(printf '%s' "$COMMAND" | tr -d "'\"")"
RE_RM_ROOT_HOME='rm[[:space:]]+(-[a-zA-Z]*[[:space:]]+)*-?[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*[[:space:]]+(/([[:space:]]|\*|$)|~|\$HOME|\$[A-Za-z_][A-Za-z0-9_]*|\.\./\.\.)'
if [[ "$STRIPPED" =~ $RE_RM_ROOT_HOME ]]; then
  deny "rm -rf against root, home, or an unresolved variable/parent-traversal path is blocked as too risky to auto-approve."
fi
PROT_REGEX="$(printf '%s' "$PROTECTED_DIRS" | tr ' ' '|')"
RE_RM_PROJECT="rm[[:space:]]+-[a-zA-Z]*rf[a-zA-Z]*[[:space:]].*($PROT_REGEX|\\.git)([[:space:]/]|\$)"
if [[ "$STRIPPED" =~ $RE_RM_PROJECT ]]; then
  deny "rm -rf targeting a protected directory ($PROTECTED_DIRS, .git) is blocked. See .claude/rules/safety.md."
fi

# --- chmod 777 / a+rwx ---
if [[ "$COMMAND" =~ chmod[[:space:]]+(777|a\+rwx) ]]; then
  deny "chmod 777 / a+rwx is almost never intentional. Confirm with the user first."
fi

# --- curl/wget piped to a shell ---
if [[ "$COMMAND" =~ (curl|wget)[[:space:]].*\|[[:space:]]*(sudo[[:space:]]+)?(bash|sh|zsh|ksh|fish|dash) ]]; then
  deny "Piping curl/wget output directly into a shell is blocked — download, inspect, then run."
fi

# --- package publish without a dry-run flag ---
if [[ "$COMMAND" =~ (npm|yarn|pnpm|bun)[[:space:]]+publish|cargo[[:space:]]+publish|gem[[:space:]]+push|twine[[:space:]]+upload ]] \
   && [[ "$COMMAND" != *"--dry-run"* && "$COMMAND" != *" -n "* ]]; then
  deny "Publishing to a package registry without --dry-run is blocked. Confirm with the user first; use --dry-run to test."
fi

exit 0
