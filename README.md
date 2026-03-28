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
- The app expects Firebase configuration files to be present. Without them Firebase initialization will fail.
- This repository focuses on architecture: strokes are stored as vectors (points, color, thickness) and stickers/presence are synced in Firestore.
- For production: tighten Firestore rules, consider batching updates and storage costs, and host sticker assets securely.