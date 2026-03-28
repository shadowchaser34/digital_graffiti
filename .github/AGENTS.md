# Agents Overview

- `DiG_dev` — Coordinator agent. Delegates tasks to other agents, sequences code changes and runtime validation, and collates reports for the user.
- `DiG_mobil` — Mobile-focused implementation agent. Makes safe, small edits to Flutter code, providers, services, and tests.
- `DiG_emulator` — Emulator and runtime validation agent. Builds, runs, and validates behavior on an Android emulator or connected device.

Coordination pattern:
1. `DiG_dev` inspects request and decides which subagent(s) to run.
2. `DiG_mobil` performs code edits when requested and returns a summary.
3. `DiG_emulator` validates runs/tests and returns logs.
4. `DiG_dev` compiles both reports and updates the todo list.

Definition of Done (Sprint-level)
1. Requested feature/fix is implemented and scoped to the sprint goal.
2. Targeted validation was executed (analyze/tests/build/run as applicable) and reported.
3. All `alpha` code paths, flags, and placeholders replaced in the sprint scope are removed; only `beta` implementation remains.
4. No leftover references to deprecated `alpha` variants remain in touched files.
5. Handoff report includes: files changed, validation performed, and any blockers.

Mandatory Alpha Gate
1. Before marking sprint done, run an explicit `alpha` leftover check on touched files (for example via grep/rg query `alpha`).
2. If any `alpha` leftovers are found in touched scope, sprint status is `NOT DONE` until cleanup is completed or the user explicitly approves deferral.
