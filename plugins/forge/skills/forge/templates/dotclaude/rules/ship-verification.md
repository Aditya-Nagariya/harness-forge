# Ship verification

A successful build is not the same as a working feature. A `TASKS.md` item may only move to `completed` after the actual behavior was exercised end-to-end, not merely after the code compiles or an isolated unit test passes.

Concretely, before marking a task `completed`:
- If it changed user-facing behavior: run the actual application/binary/endpoint and look at real output, not just the test suite.
- If it's a guardrail (validation, limit, timeout): trigger the refusal/failure path for real once — don't just unit-test the arithmetic.
- State how it was verified in the `TASKS.md` entry (or `ARCHIVE.md` once moved): "verified: ran <exact command>, observed <specific result>" — not just "done."

Rationale: exit-0-while-semantically-failing is the single most common silent failure mode in automated work; the verification statement makes every "done" claim falsifiable.
