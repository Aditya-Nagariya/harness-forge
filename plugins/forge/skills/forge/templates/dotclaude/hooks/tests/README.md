# Hook tests

JSON-fixture + bash-runner pattern. Only the deterministic, side-effect-free content-scanning/blocking hooks are covered (`protect-files`, `scan-secrets`, `block-dangerous-commands`, `capture-failure`, `notify`) — `update-status.sh`/`auto-test.sh`/`format-on-save.sh`/`session-start.sh`/`session-end.sh`/`pre-compact.sh`/`bump-updated.sh`/`issue-capture-reminder.sh` all compute their working paths from their own script location (so they always operate on the *real* project tree, not a sandbox) and/or run real build/test commands — running them through this harness would pollute real project state (`activity-log.md`, `state/edit-counts.txt`) or take real build time. Verify those by running the real hook against a throwaway scratch directory instead (copy the script + a minimal `.claude/` skeleton into `/tmp`, invoke it there, inspect the result).

Run: `bash .claude/hooks/tests/run-all.sh` (requires `jq`).

## Fixture format

`fixtures/<hook-name>/NN-description.json`:

```json
{
  "name": "human readable description",
  "stdin": { "tool_input": { "...": "..." } },
  "expect_exit": 0,
  "expect_stdout_contains": ["substring", "..."],
  "expect_stdout_not_contains": ["substring", "..."],
  "env": { "VAR": "value" }
}
```

`stdin` is the object piped as JSON into the hook script (matching what Claude Code actually sends). `expect_exit` is the required exit code. The two `expect_stdout_*` arrays are optional substring checks against stdout.

## Adding a fixture

Cover both the allow and the deny/ask path for any new pattern, plus edge cases that could plausibly false-positive or false-negative: quoted arguments, allow-listed flags (`--force-with-lease`, `--dry-run`), and paths that look similar to a protected one but aren't (e.g. `dist/` vs a real protected dir).

## Fake-secret hygiene

`scan-secrets`'s fixtures necessarily contain fake credential-shaped strings (`AKIAABCDEFGHIJKLMNOP`, a fake RSA private key block). These are obviously-fake placeholders, never a real or even revoked credential — if a secret scanner is ever added to this repo's CI, allowlist `.claude/hooks/tests/fixtures/scan-secrets/**` explicitly rather than disabling the scanner.
