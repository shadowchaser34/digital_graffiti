# Digital Graffiti Wall

Minimal collaborative drawing wall using Firebase + Riverpod.

## FastAPI device launcher

This repository now includes a minimal FastAPI dashboard in `backend/` for starting an Android emulator or launching the Flutter app on a connected Android device.

1. Install Python 3.10+ and make sure a real `py -3` or `python` installation is available on your PATH, along with `flutter`. The Windows Store `python.exe` alias is not enough.
2. From the repo root, install the backend dependencies:

```bash
python -m pip install -r backend/requirements.txt
```

3. Start the dashboard:

```bash
backend\run_dashboard.bat
```

4. Open `http://127.0.0.1:8000` in a browser.

The dashboard lists Flutter devices and emulators by calling the Flutter CLI, can start an emulator with `flutter emulators --launch <emulator_id>`, and can start the app with `flutter run -d <device_id>`. Use the Stop button to end the most recent launch.

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