# Plant Doctor (mobile app)

Flutter app for the Smart Agriculture System — see the
[repo root README](../README.md) for the full project. This app is
the unified control surface for both ESP32 nodes and the AI diagnosis
features:

- **Sensor Dashboard** — live temperature/humidity/soil moisture from
  the irrigation node
- **Irrigation Control** — manual/automatic mode, pump on/off
- **Disease Diagnosis** — photo diagnosis via Gemini Vision, or poll
  the vision node's on-device result
- **History** — local log of past diagnoses and sensor snapshots
- **Chatbot** — domain-restricted plant-care assistant (Gemini)
- **Device Tests** — connectivity check for both ESP32 nodes

## Setup

```bash
flutter pub get
cp .env.example .env   # fill in your Gemini API key and node IPs
flutter run
```

See [`../docs/bring-up-checklist.md`](../docs/bring-up-checklist.md)
for full setup details, and [`../docs/wiring.md`](../docs/wiring.md)
for the ESP32 hardware this app talks to.

## Building a release APK

```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`. Requires a
complete Android SDK (`flutter doctor` should show no `[X]` under the
Android toolchain) -- not verified in this project's dev environment,
where the Android SDK's `cmdline-tools` component and licenses were
incomplete (see [`../docs/flutter-runtime.md`](../docs/flutter-runtime.md)).
Install the resulting APK on a device or emulator with
`adb install app-release.apk`, or `flutter install` with a device
connected.

For iOS, this project has no Apple Developer account or macOS build
environment behind it -- `flutter build ios` and code signing are
standard Flutter steps, but genuinely untested here.

## Verified, not just written

```bash
flutter analyze   # clean
flutter test      # passing
```

Both run automatically in CI on every push (see the badge on the repo
root README). Hasn't been run on a physical device/emulator in the
environment this was built in — see the root README for that caveat.
