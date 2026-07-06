Summary: Parse agent/skill YAML frontmatter with a real parser after writing it; quote values containing `:`/`#`/brackets.

---
id: 0002
date: 2026-07-04
trigger: Writing or editing any file with YAML frontmatter (.claude/agents/*.md, .claude/skills/*/SKILL.md, rules with paths:).
weight: 1.0
occurrences: 1
status: active
---

## Failure pattern

Agent/skill files that looked correct on read-back were broken YAML: an unquoted colon inside a description's parenthetical made YAML see a nested mapping (`mapping values are not allowed here`), and a `#`-after-space inside a bracketed `argument-hint` was swallowed as a YAML comment, leaving an unterminated sequence. Consequence if unchecked: Claude Code silently de-registers the agent — no error until spawn time ("Agent type not found"), potentially days later and disconnected from the edit that caused it.

## Correction

A deliberate `yaml.safe_load()` validation pass over every frontmatter block, before committing.

## Rule

Quote the whole `description`/`argument-hint` value whenever it contains a colon, `#`, or brackets. After writing frontmatter, run it through a real YAML parser before considering the file done. (This repo carries a permanent regression check: `evals/regressions/0001-frontmatter-parses.sh`, also run by `/harness-audit` and validate.)

## Why it mattered

The failure is silent and deferred — the most expensive kind to debug.
