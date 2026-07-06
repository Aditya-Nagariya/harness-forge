#!/usr/bin/env bash
# Regression check for lesson 0005: no hook/script may pipe data into a command
# that also uses a heredoc on the same command — the heredoc silently steals
# stdin and the piped data is lost (this broke the SEC-1 gate once: it silently
# allowed everything). Pattern: a `|` followed by an interpreter and a heredoc
# marker on one line.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

if grep -rnE '\|[[:space:]]*(python3?|bash|sh|node)[^|]*<<' \
    .claude/hooks .claude/scripts .claude/statusline.sh 2>/dev/null \
    | grep -v "tests/fixtures"; then
  echo "pipe-into-heredoc pattern found (see lesson 0005) - the piped stdin is silently lost"
  exit 1
fi
exit 0
