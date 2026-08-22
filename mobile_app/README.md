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
Output: `build/app/outputs/flutter-apk/app-release.apk`. **Actually
builds** -- verified by really running it, producing a real ~20.7 MB
APK, not assumed from `flutter doctor` looking clean. Getting there
required a genuine fix: the project's default Gradle 7.6.3 / AGP 7.3.0
/ Kotlin 1.7.10 combination doesn't support JDK 21 (what Android
Studio's bundled JDK currently ships), so the build failed until
bumped to Gradle 8.4 / AGP 8.1.0 / Kotlin 1.9.24, with an explicit
`kotlinOptions.jvmTarget = "1.8"` added to keep bytecode output
matching the existing `compileOptions` (Gradle 8's Kotlin plugin
otherwise infers the target from the JDK, not from `compileOptions`,
which produced a second, different mismatch error). See
[`../docs/flutter-runtime.md`](../docs/flutter-runtime.md) for the full
diagnosis.
Install the resulting APK on a device or emulator with
`adb install app-release.apk`, or `flutter install` with a device
connected -- **that install/launch step itself has not been done**;
the APK's existence is verified, its behavior on a real device is not.

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
