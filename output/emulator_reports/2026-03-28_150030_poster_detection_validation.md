# Runtime Validation Report

## Summary
The app builds and starts on Android. On the emulator, the camera-first path reaches preview and image-stream startup, which means the overlay/detection pipeline is live. On the physical Pixel 7, startup reaches the camera stack but the camera plugin reports `onError` and closes, so full live poster detection could not be positively exercised on that device.

## Files Inspected
- [lib/main.dart](lib/main.dart)
- [lib/screens/home_screen.dart](lib/screens/home_screen.dart)
- [lib/widgets/camera_background.dart](lib/widgets/camera_background.dart)
- [lib/services/poster_detection_service.dart](lib/services/poster_detection_service.dart)
- [lib/widgets/canvas_widget.dart](lib/widgets/canvas_widget.dart)
- [pubspec.yaml](pubspec.yaml)

## What Was Validated
- The app entrypoint initializes Flutter, attempts Firebase initialization, and continues even if Firebase is unavailable.
- `HomeScreen` uses `CameraBackground` as the root body, so the app is camera-first.
- The camera overlay stack is present: canvas, participant indicator, and toolbar are layered over the camera surface.
- On the emulator, the camera plugin successfully reached `startPreview` and `startPreviewWithImageStream`.
- On the Pixel 7, the app built, installed, and reached the camera service before the camera backend returned `onError`.

## What Passed
- App build and install succeeded on both targets.
- App startup succeeded on both targets.
- Emulator camera initialization succeeded far enough to start preview and the image stream.
- No startup crash was observed from Firebase initialization or the overlay stack.

## What Blocked Completion
- The physical Pixel 7 camera path failed at runtime with `I/Camera: open | onError` followed by `close`, so I could not confirm a successful live poster-detection match on that device.
- No explicit detection-match logging exists in the inspected code, so a positive poster-identification event could only be inferred from camera stream activity, not directly observed in logs.

## Log Entries
### info
- `flutter run` built and installed `build/app/outputs/flutter-apk/app-debug.apk` on the Pixel 7.
- `flutter run` built and installed `build/app/outputs/flutter-apk/app-debug.apk` on the emulator.
- Emulator logs showed `startPreview` and `startPreviewWithImageStream`.

### debug
- Flutter rendered with Impeller on both targets.
- The camera stack connected to the system camera service on the physical device.
- The overlay/canvas path was mounted through `HomeScreen` and `CameraBackground`.

### warning
- The Pixel 7 log reported `Skipped frames`, indicating a heavy startup path during initialization.
- The physical device camera plugin emitted `open | onError`, then `close`.
- Emulator startup produced repeated `Width is zero. 0,0` renderer messages before viewport metrics settled.

### error
- Physical device camera initialization did not complete cleanly: `I/Camera: open | onError`.
- The camera session on the physical device emitted `LegacyMessageQueue` warnings tied to the failed camera closure path.
