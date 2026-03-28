# Agents Overview

- `DiG_dev` — Coordinator agent. Delegates tasks to other agents, sequences code changes and runtime validation, and collates reports for the user.
- `DiG_mobil` — Mobile-focused implementation agent. Makes safe, small edits to Flutter code, AR anchor workflows, providers, services, and tests.
- `DiG_emulator` — Emulator and runtime validation agent. Builds, runs, and validates behavior on an Android emulator or connected device, including camera and Firebase setup.

Coordination pattern:
1. `DiG_dev` inspects request and decides which subagent(s) to run.
2. `DiG_mobil` performs code edits when requested and returns a summary.
3. `DiG_emulator` validates runs/tests and returns logs.
4. `DiG_dev` compiles both reports and updates the todo list.

Output organization:
1. `output/mobil_reports/` stores implementation reports from `DiG_mobil`.
2. `output/emulator_reports/` stores validation reports from `DiG_emulator`.
3. Use timestamped filenames to keep sprint evidence traceable.
4. Reports should include structured log sections with `info`, `debug`, `warning`, and `error` entries.

Documentation expectations:
1. New code should include docstrings or short comments only where behavior is not obvious.
2. Keep comments concise and tied to implementation intent, not trivial line-by-line narration.
