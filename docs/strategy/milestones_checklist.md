# Milestones Checklist

Use this checklist to track completion of each milestone and required verification steps.

## Sprint 1 — Project scaffold, anchor catalog & Firebase
- [ ] Create Flutter project and repo
- [ ] Add `pubspec.yaml` with required deps
- [ ] Add Firebase initialization code (`main.dart`) and platform config placeholders
- [ ] Register poster anchors from `docs/project_definition/poze`
- [ ] Verify anonymous auth works locally
- Verification: `flutter run` starts without Firebase config errors (or shows clear config message); poster anchors can be listed from the local asset set

## Sprint 2 — Poster mapping & Local Canvas
- [ ] Detect poster anchor and map coordinates to the canvas
- [ ] Implement `CustomPainter` drawing
- [ ] Store strokes locally as vector (points)
- [ ] Add brush color and thickness UI
- Verification: Draw locally; strokes replay and undo locally; drawing stays aligned to the same poster anchor

## Sprint 3 — Real-time sync (Firestore)
- [ ] Add Firestore streams for `strokes` and `stickers`
- [ ] Send only newly completed strokes to Firestore
- [ ] Handle concurrency and ordering (timestamps)
- [ ] Sync collaborative presence and per-anchor state
- Verification: Two devices show strokes in <1s after save; presence changes are visible on the same anchor

## Sprint 4 — Stickers, media & audio
- [ ] Add sticker picker UI
- [ ] Place stickers with normalized `x,y`, `scale`, `rotation`
- [ ] Persist stickers to Firestore and render on all clients
- [ ] Support anchored PNG / GIF / image media
- [ ] Trigger attached audio when another user scans the poster
- Verification: Sticker placed on device A appears at same normalized position on device B; media and audio attach to the same poster anchor

## Sprint 5 — Territory, Presence, Undo/Redo, Polishing
- [ ] Presence docs & visual indicators
- [ ] Per-user undo/redo persisted (delete stroke doc / re-add)
- [ ] Throttle presence updates to reduce write cost
- [ ] Territory engine and team ownership view
- [ ] Bonus effects: glitch / haptics / AI tag generator hooks
- Verification: Presence indicators update while users draw; undo only removes your strokes; territory view updates after activity changes

## Notes
- For each checklist item include: files changed, tests run, and any manual validation steps.
- Use `docs/project_definition/poze` as the canonical poster-anchoring reference set during implementation and testing.

## Definition of Done for Each Sprint
- The sprint is only done if the code compiles, the relevant tests pass, and the implementation report is saved under the correct `output/` subfolder.
- The report must include a log section with `info`, `debug`, `warning`, and `error` entries.
- The implementation should include short docstrings or comments for new code only when the intent is not obvious.
- A sprint cannot close if the targeted user flow is unvalidated on emulator or device.
