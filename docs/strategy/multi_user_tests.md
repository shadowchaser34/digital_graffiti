# Multi-user Test Cases

This document lists manual and automated test scenarios to validate multi-user collaboration.

## Manual test: Poster anchor scan
1. Setup: Launch the app on Device A and Device B (or emulator + device). Authenticate anonymously. Use one of the reference posters from `docs/project_definition/poze`.
2. Action: Scan the same poster on both devices.
3. Expectation: Both devices open the same anchored canvas and preserve the same poster-relative coordinate system.
4. Validation: Verify the same poster ID / anchor is selected and the content sits in the same place.

## Manual test: Two-device drawing
1. Setup: Launch the app on Device A and Device B (or emulator + device). Authenticate anonymously.
2. Action: On Device A, draw a stroke and finish it.
3. Expectation: The stroke appears on Device B within ~1 second.
4. Validation: Verify stroke color, thickness, and shape match.

## Manual test: Sticker and media placement
1. Setup: Device A and B connected.
2. Action: On Device A, open sticker picker and place a sticker at the center; repeat with PNG / GIF media if available.
3. Expectation: Content appears at the same relative position on Device B.
4. Validation: Confirm normalized coordinates, rotation, and scale are preserved.

## Manual test: Concurrent drawing
1. Setup: Device A and B.
2. Action: Both devices draw at the same time in nearby areas.
3. Expectation: Strokes from both users appear without overwriting; timestamps preserve order per-stroke.

## Manual test: Undo/Redo per user
1. Action: On Device A draw three strokes. Press Undo once.
2. Expectation: Only the most recent stroke by Device A is removed on both devices.
3. Redo: Redo should re-add the stroke for Device A only.

## Manual test: Audio trigger on rival scan
1. Setup: Attach an audio file to a poster anchor and open the app on Device A and Device B.
2. Action: Device B scans the same poster after Device A has attached audio.
3. Expectation: The sound plays automatically on the scanning device.
4. Validation: Confirm the audio is tied to the poster anchor and not the individual user.

## Manual test: Territory update
1. Setup: Two users active on the same poster.
2. Action: Have one user draw or place multiple items on the poster.
3. Expectation: The territory / ownership indicator updates for all clients.
4. Validation: Confirm the status changes after activity thresholds or ownership rules are met.

## Manual test: Bonus effects smoke test
1. Setup: Enable any implemented bonus feature.
2. Action: Trigger glitch / haptics / AI tag generator if present.
3. Expectation: Bonus effects do not break drawing, sync, or scanning.
4. Validation: Confirm the core poster interaction still works after the effect fires.

## Automated test ideas
- Unit test for `Stroke.toMap()` and `Stroke.fromMap()` roundtrip.
- Integration test mocking Firestore to assert that only new stroke documents are created per completed stroke.
- Unit test for poster-anchor coordinate mapping using the reference poster set.
- Unit test for `Sticker.toMap()` / `Sticker.fromMap()` and normalized position roundtrip.
- Integration test for audio-trigger state tied to the poster anchor instead of a single user session.

## Diagnostics collection
- Collect: timestamps, user ids, stroke ids, presence updates.
- When a sync problem is reported, use these logs to trace missing documents or rule-based denial.
