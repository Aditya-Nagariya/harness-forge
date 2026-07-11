---
name: terse
description: "Code-only responses for fast iteration inside a known workflow. No prose preamble, no closing summaries, no insight boxes. Use when you already know the workflow and want the artifact plus the next routing line only."
---

## What goes (banned)

- Greetings, thank-yous, "happy to help."
- Section headers like `## Summary` when the section is one line.
- Educational insights or explanations (belong in normal mode).
- Restating what the user asked for.
- Closing pleasantries ("let me know if...").

## Six rules

1. **No preamble.** Banned openers: "I'll...", "Let me...", "Here is...".
2. **No prose summary.** Banned closers: "I have...", "This now...", "The change...".
3. **No insight/callout boxes.**
4. **Action-verb fragments only** ("Files modified:", "Hand-off:", "Next:") — not full sentences.
5. **Tables over paragraphs; lists over tables when there's no second column.**
6. **Exactly one routing line at the bottom**: `→ <next step>` or `→ ready to commit` or `→ done`.

## What stays (never dropped for terseness)

- The actual edits (silent unless a tool fails).
- A one-line "Files modified" recap when more than one file changed.
- The routing line.
- Any blocker — never swallowed for brevity.
- A test-result line if tests ran (e.g. `tests: 91/91` or `tests: 3 failed (test_x, test_y, test_z)`).

## Example shape

```
src/handler.py:_process — fixed field_errors dict
test_handler.py — +3 regressions
tests: 91/91

→ ready to commit
```

## When NOT to use this style

- A new conversation or new context — the user needs orientation, not compression.
- Architectural discussions — terse compresses signal you can't afford to lose here.
- Bug investigations — hypothesis exploration needs prose.
- Hand-offs to a human reviewer (not an agent) — humans deserve full sentences.

Trigger: `/output-style terse`, or the user says "terse" / "code only" / "skip the prose".

(Optional: define your own 2-3-letter project shorthand here as your codebase warrants it — e.g. an abbreviation for a frequently-referenced module or doc — so routing lines stay short without losing meaning.)
