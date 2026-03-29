# Missing Emulator Window Validation Report

Date: 2026-03-29
Project: c:/digital_graffiti_wall
Scope: Read-only inspection of Flutter/VS Code/Android launcher guidance on Windows

## Result Summary
- Overall: PASS for diagnosis, no app code change needed
- Most likely cause: the current VS Code Flutter launch starts the app on an available device target, but it does not start an Android emulator window by itself
- Validation note: Flutter saw a connected Pixel 7 and the Windows host, but no emulator was launched from the current workspace config

## Evidence
1) `.vscode/launch.json`
- Uses the Dart debugger with `program: lib/main.dart`
- No emulator startup command, no AVD launch task, and no explicit Android device target are defined

2) `README.md`
- Quick start only says to run `flutter pub get` and `flutter run`
- It does not explain that an emulator must be opened separately in Android Studio or via the Flutter CLI

3) `flutter devices`
- PASS
- Output:
  - Pixel 7 (mobile) • 34061FDH2000M1 • android-arm64 • Android 16 (API 36)
  - Windows (desktop)
  - Chrome
  - Edge

4) `flutter emulators`
- PASS
- Output indicated emulator management help, but no emulator was launched by the workspace

## User-Facing Diagnosis
- The app can start on an already connected device or the Windows desktop target without any emulator window appearing.
- If the goal is to see the Android emulator UI, the emulator must be launched first.
- The current workspace config does not include a launcher that automatically opens an AVD.

## Steps To Make The Emulator Visible
1) In Android Studio, open Device Manager and start an existing AVD, or create one if none exists.
2) In VS Code, select the Android emulator in the device picker before pressing Run.
3) If you prefer the terminal, start the emulator first with `flutter emulators --launch <emulator_id>` after creating/configuring an AVD.
4) Then run the app with `flutter run -d <emulator_id>` or use VS Code Run once the emulator is already running.
5) If a physical Pixel is connected, disconnect it or explicitly choose the emulator so Flutter does not deploy to the phone instead.

## App Code Change Needed
- No app-side code change is needed to make the emulator window appear.
- This is a launcher/device-selection issue, not an app runtime bug.

## Structured Logs
- info: Inspected README and VS Code launch settings for Flutter-on-Windows run guidance.
- info: Ran `flutter devices` and confirmed Flutter can see a physical Android device plus Windows/web targets.
- debug: `.vscode/launch.json` launches `lib/main.dart` through the Dart debugger and does not start an emulator.
- warning: No emulator-launch step is defined in the workspace config, so the emulator window will not appear automatically.
- warning: A connected Pixel 7 is available, so Flutter may run there unless the emulator is selected explicitly.
- error: None.

## Validation Verdict
- Requested objective completed: YES
- Code changes required: NO
- If the user wants the emulator window specifically, they must start/select an emulator separately before running the app.