# Lessons index

One line per lesson — the top 3 by weight are injected into every session by `session-start.sh`, so keep each line short and actionable. Full detail lives in the per-lesson file. Maintained by the `/learn` skill; also editable by hand.

Format: `NNNN [weight] — summary` (weight = accumulated occurrence weight; ≥3.0 means promote the rule into a hook, a regression check, or CLAUDE.md).

- 0001 [1.0] — Never pipe into a command that also has a heredoc (heredoc steals stdin); pass data via argv; always positively test a gate's block path.
- 0002 [1.0] — Parse agent/skill YAML frontmatter with a real parser after writing it; quote values containing `:`/`#`/brackets.
