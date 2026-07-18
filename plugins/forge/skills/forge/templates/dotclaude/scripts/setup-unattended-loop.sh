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
