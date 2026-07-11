# small-executor memory

Institutional knowledge accumulated across runs. Keep entries to one or two lines; curate when this file grows past ~150 lines.

## Codebase map

- (fill in as you discover it: entry points, module layout, where config lives)

## Gotchas

- Your memory lives in FILES under `.claude/agent-memory/small-executor/` — Read `MEMORY.md` (the file), never the directory path itself.
- A PostToolUse hook may auto-format/re-run build+lint after every edit — expect the file to change under you; re-read before a second edit of the same file.
