---
name: loop
description: "Run one iteration of this project's maintenance loop: finish in-flight work, convert failures into lessons, checkpoint hygiene, audit the harness, or start the next pending task — whichever is highest-value right now. Also the remedy when capability-gate.sh blocks a source edit because maintenance is overdue."
---

Read `.claude/loop.md` and follow it exactly — it is the single source of truth for the loop's step ordering, its unattended-mode rules, and its Step 0/final-step timestamp stamping. Do not improvise a different order or skip Step 0 (`bash .claude/scripts/record-loop-run.sh`): that stamp is what tells `capability-gate.sh` the loop ran, and stamping first is what lets the loop's own source edits through the gate.
