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

## Verified, not just written

```bash
flutter analyze   # clean
flutter test      # passing
```

Both run automatically in CI on every push (see the badge on the repo
root README). Hasn't been run on a physical device/emulator in the
environment this was built in — see the root README for that caveat.
