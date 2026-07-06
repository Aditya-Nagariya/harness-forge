Summary: Never pipe into a command that also has a heredoc (heredoc steals stdin); pass data via argv; always positively test a gate's block path.

---
id: 0001
date: 2026-07-04
trigger: Writing any shell pattern combining a pipe with a heredoc on the same command, or shipping any blocking gate/hook.
weight: 1.0
occurrences: 1
status: active
---

## Failure pattern

A PreToolUse security hook did `printf '%s' "$INPUT" | python3 - <<'PY' ... json.load(sys.stdin) ... PY`. The heredoc redirects stdin, so the piped JSON never reached the Python script — the gate silently allowed everything (exit 0, no error). A test that should have blocked came back allow.

## Correction

Pass the data via argv instead: `python3 - "$INPUT" <<'PY' ... json.loads(sys.argv[1]) ... PY`. Retested: gate blocked correctly with exit 2.

## Rule

Never combine a pipe into a command with a heredoc on that same command — the heredoc silently replaces the piped stdin. Pass the data as an argument or a temp file. And always positively test a security gate's *block* path — a gate whose failure mode is "silently allow" must be demonstrated to fire, never assumed. (This repo carries a permanent regression check for the pattern: `evals/regressions/0002-no-pipe-into-heredoc.sh`.)

## Why it mattered

It was a security enforcement gate. Its failure mode was invisible: everything kept working, just without protection.
