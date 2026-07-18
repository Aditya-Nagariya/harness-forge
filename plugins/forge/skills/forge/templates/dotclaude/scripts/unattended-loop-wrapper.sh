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
