# Agents Overview

- `DiG_dev` — Coordinator agent. Delegates tasks to other agents, sequences code changes and runtime validation, and collates reports for the user.
- `DiG_mobil` — Mobile-focused implementation agent. Makes safe, small edits to Flutter code, providers, services, and tests.
- `DiG_emulator` — Emulator and runtime validation agent. Builds, runs, and validates behavior on an Android emulator or connected device.

Coordination pattern:
1. `DiG_dev` inspects request and decides which subagent(s) to run.
2. `DiG_mobil` performs code edits when requested and returns a summary.
3. `DiG_emulator` validates runs/tests and returns logs.
4. `DiG_dev` compiles both reports and updates the todo list.
