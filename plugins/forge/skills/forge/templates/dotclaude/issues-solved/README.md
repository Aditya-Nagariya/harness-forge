# issues-solved

A bug database, not a general notes file. Before debugging anything non-trivial, grep `INDEX.md` for the symptom's keywords first.

**Protocol:**
1. Hit a bug → grep `INDEX.md` for symptom keywords / error-message fragments.
2. Match found → read the linked file, apply the known fix, don't re-derive from scratch.
3. No match → solve it, then add an entry (see below) **if** it meets the threshold.

**Add an entry when:** it took >2 debugging iterations, OR >5 minutes, OR required external research (docs, issue trackers, crate source).

**Don't add an entry for:** feature work, architecture decisions (→ `memory/decisions.md`), Claude-behavior corrections (→ `memory/lessons.md`), or anything solved in under 2 iterations.

**Adding an entry:**
1. Copy `TEMPLATE.md` to `NNNN-short-slug.md` (zero-padded, 4 digits, next free number — check `INDEX.md`, don't reuse a gap).
2. Fill it in, including "Failed attempts" if you tried something that didn't work — that's as valuable as the fix.
3. Prepend a row to `INDEX.md`.
