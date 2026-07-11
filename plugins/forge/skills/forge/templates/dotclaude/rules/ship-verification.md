# Ship verification

A successful build ≠ a working feature.

| Layer | "Pass" signal | What it proves |
|---|---|---|
| Transport | HTTP 200, a handshake, "no exception" | The pipe is open |
| **Feature** | The field got the **right value** / the right thing happened | It actually works |

`completed` requires the Feature row, not just Transport.

Before marking a task `completed`:
1. Run the real behavior end-to-end, look at real output — not just the test suite.
2. Two-sided protocol? Simulate the other side properly (send the ack/handshake the server waits on), or the feature silently dies as it would against a broken client.
3. Guardrail (validation/limit/timeout)? Trigger the real refusal path once — don't just unit-test the arithmetic.
4. Verifying a running/deployed instance? Confirm it actually loaded the change (version check/restart), not just "the local source has the fix."
5. **Never round up** — an unproven sub-step is "transport verified, feature UNVERIFIED," not "done."
6. Save non-trivial verification as a committed, re-runnable script so the next ship re-verifies in one step.
7. State how it was verified in `TASKS.md`/`ARCHIVE.md`: `verified: ran <exact command>, observed <result>`.

Rationale: exit-0-while-semantically-failing is the most common silent failure mode; the verification statement makes "done" falsifiable.
