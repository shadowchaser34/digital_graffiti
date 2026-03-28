# Digital Graffiti Wall

Minimal collaborative drawing wall using Firebase + Riverpod.

Run (quick start):

1. Create a Firebase project at https://console.firebase.google.com
2. Enable Authentication -> Anonymous and create a Firestore database (in production use rules!).
3. Add platform config files:
	- Android: place `google-services.json` into `android/app/`
	- iOS/macOS: place `GoogleService-Info.plist` into `ios/Runner/` (and add to Xcode project)
4. From project root run:

```bash
flutter pub get
flutter run
```

Notes:
- The app will still launch on Android if Firebase is not configured, but it falls back to local-only mode and won’t sync between devices.
- For full collaborative mode on a Pixel, keep `google-services.json` in `android/app/` and make sure the Android Google Services plugin is applied.
- This repository focuses on architecture: strokes are stored as vectors (points, color, thickness) and stickers/presence are synced in Firestore.
- For production: tighten Firestore rules, consider batching updates and storage costs, and host sticker assets securely.