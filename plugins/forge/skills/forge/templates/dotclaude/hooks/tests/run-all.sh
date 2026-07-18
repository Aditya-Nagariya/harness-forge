#!/usr/bin/env bash
# Hook test runner: for each fixtures/<hook>/*.json, pipe .stdin into hooks/<hook>.sh
# and check exit code + stdout substrings. Adapted from dotclaude-main's
# hooks/tests/run-all.sh pattern. CI-friendly: exits 1 on any failure.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required to run hook tests (brew install jq)." >&2
  exit 1
fi

pass=0
fail=0

for hook_dir in "$FIXTURES_DIR"/*/; do
  hook_name="$(basename "$hook_dir")"
  hook_script="$HOOKS_DIR/${hook_name}.sh"

  if [ ! -f "$hook_script" ]; then
    echo "SKIP: no hook script found for fixtures/$hook_name (expected $hook_script)"
    continue
  fi

  for fixture in "$hook_dir"*.json; do
    [ -e "$fixture" ] || continue

    name="$(jq -r '.name' "$fixture")"
    stdin_json="$(jq -c '.stdin' "$fixture")"
    expect_exit="$(jq -r '.expect_exit' "$fixture")"

    env_args=()
    while IFS='=' read -r k v; do
      [ -z "$k" ] && continue
      env_args+=("$k=$v")
    done < <(jq -r '.env // {} | to_entries[] | "\(.key)=\(.value)"' "$fixture")

    stage_dir=""
    for kv in "${env_args[@]+"${env_args[@]}"}"; do
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

    stdout_file="$(mktemp)"
    stderr_file="$(mktemp)"
    printf '%s' "$stdin_json" | env "${env_args[@]+"${env_args[@]}"}" bash "$hook_script" >"$stdout_file" 2>"$stderr_file"
    actual_exit=$?

    ok=1
    reason=""

    if [ "$actual_exit" != "$expect_exit" ]; then
      ok=0
      reason="exit code: expected $expect_exit, got $actual_exit"
    fi

    if [ "$ok" = "1" ]; then
      while IFS= read -r needle; do
        [ -z "$needle" ] && continue
        if ! grep -qF "$needle" "$stdout_file"; then
          ok=0
          reason="stdout missing expected substring: $needle"
          break
        fi
      done < <(jq -r '.expect_stdout_contains // [] | .[]' "$fixture")
    fi

    if [ "$ok" = "1" ]; then
      while IFS= read -r needle; do
        [ -z "$needle" ] && continue
        if grep -qF "$needle" "$stdout_file"; then
          ok=0
          reason="stdout contains forbidden substring: $needle"
          break
        fi
      done < <(jq -r '.expect_stdout_not_contains // [] | .[]' "$fixture")
    fi

    if [ "$ok" = "1" ]; then
      echo "PASS: $hook_name / $name"
      pass=$((pass + 1))
    else
      echo "FAIL: $hook_name / $name -- $reason"
      echo "  stdout: $(cat "$stdout_file")"
      echo "  stderr: $(cat "$stderr_file")"
      fail=$((fail + 1))
    fi

    rm -f "$stdout_file" "$stderr_file"
  done
done

echo ""
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
