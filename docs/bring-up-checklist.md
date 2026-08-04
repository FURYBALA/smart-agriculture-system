# Bring-up checklist

Nothing in this repo has been run on real hardware in the environment
it was built in (no ESP32 toolchain, no physical boards, no Android/iOS
emulator). Everything below was written carefully and reviewed against
the correct APIs, but go through this checklist rather than assuming
it just works.

## Irrigation node (`firmware/irrigation_node`)

1. Install libraries: **DHT sensor library** (Adafruit) + **Adafruit
   Unified Sensor**, **ArduinoJson**.
2. Set `WIFI_SSID` / `WIFI_PASSWORD` in `config.h`.
3. Calibrate the soil sensor first (see `docs/wiring.md`) — the
   default `SOIL_RAW_DRY`/`SOIL_RAW_WET` values are placeholders.
4. Flash, open Serial Monitor at 115200 baud, note the printed IP
   address.
5. Confirm the REST API: `curl http://<ip>/sensors` should return
   JSON. If the pump runs immediately on boot, flip
   `RELAY_ACTIVE_LOW` in `config.h`.

## Vision node (`firmware/vision_node`)

1. Install a TFLite Micro port for Arduino/ESP32 (e.g.
   `TensorFlowLite_ESP32` or `Chirale_TensorFlowLite`) — confirm the
   `tensorflow/lite/micro/...` header paths match what's used in
   `vision_node.ino`; these shift slightly between library versions.
2. Enable PSRAM in board settings (required for the camera frame
   buffer + tensor arena together).
3. `kTensorArenaSize` in `config.h` (250 KB) is a reasoned estimate
   for this model's layer sizes, not a measured value. If
   `AllocateTensors()` fails on first boot, increase it and reflash —
   normal for a first bring-up.
4. Point the camera at a printed photo of a healthy vs. diseased leaf
   and confirm Serial output tracks. The model was trained on
   PlantVillage's cropped, plain-background photos (see
   `docs/dataset.md`) — expect lower accuracy on real garden photos
   with cluttered backgrounds until fine-tuned on real deployment
   images.
5. Confirm `curl http://<ip>/latest` returns JSON with a class and
   confidence.

## Mobile app (`mobile_app`)

Verified with `flutter analyze` (clean) and `flutter test` (passing)
— but never run on a device or emulator. Before a real run:

1. `flutter pub get`
2. Copy `.env.example` to `.env` and fill in:
   - `GEMINI_API_KEY` — from [aistudio.google.com/apikey](https://aistudio.google.com/apikey)
   - `IRRIGATION_NODE_HOST` / `VISION_NODE_HOST` — the IPs printed by
     each node's Serial output
3. `flutter run` on a connected device or emulator on the **same
   Wi-Fi network** as both ESP32 nodes.
4. If `sqflite` errors on first run, it usually means a missing
   platform-specific setup step for your target (Android/iOS) — see
   the [sqflite package docs](https://pub.dev/packages/sqflite).

## Cloud backend (`backend`)

Not deployed — see `backend/README.md` for the `sam build --use-container
&& sam deploy --guided` steps and the model-file/class-label sync step
required before it'll return correct results.
