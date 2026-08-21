# Local ESP32 simulation

There's no physical ESP32 or ESP32-CAM available in this project's dev
environment (see [`docs/bring-up-checklist.md`](bring-up-checklist.md)).
This is the closest practical substitute: a local server that speaks the
*exact same REST contract* as the real firmware, so the real, unmodified
Flutter app can be pointed at it and actually exercised end-to-end.

**This is a development/testing aid, not hardware validation.** It
proves the app's networking, JSON parsing, and error-handling code
behaves correctly against realistic responses. It proves nothing about
Wi-Fi behavior, sensor accuracy, relay wiring, or anything else that
only exists once there's a real board — see
[`docs/bring-up-checklist.md`](bring-up-checklist.md) for what's still
pending there.

## What it simulates

`mobile_app/tool/esp32_simulator_lib.dart` implements two local HTTP
servers matching:

- `firmware/irrigation_node/irrigation_node.ino`'s REST handlers
  (`handleGetSensors`, `handleGetMode`/`handleSetMode`,
  `handlePumpOn`/`handlePumpOff`) -- same JSON field names, same status
  codes (including the 409 "switch to manual mode first" guard).
- `firmware/vision_node/vision_node.ino`'s `handleLatest` -- same
  `{class, confidence, hasResult, ageMs}` shape.

It is **not** a reimplementation of the firmware's pump/timer logic --
that's exercised for real in
[`docs/host-testing.md`](host-testing.md)'s host-side tests. This is
just realistic, controllable HTTP responses shaped exactly like the real
device's.

## Running it standalone

```bash
cd mobile_app
dart run tool/esp32_simulator.dart
```

Then point `.env` at it instead of a real device:

```
IRRIGATION_NODE_HOST=127.0.0.1:8090
VISION_NODE_HOST=127.0.0.1:8091
```

`flutter run` (on whatever device/runtime target is available) now talks
to the simulator through the exact same `Esp32Service` code path it
would use with real hardware.

Switch scenarios live, from another terminal, without restarting:

```bash
curl -X POST http://127.0.0.1:8090/simulator/scenario -d '{"scenario":"low_moisture"}'
curl http://127.0.0.1:8090/simulator/scenarios   # list what's available
curl -X POST http://127.0.0.1:8091/simulator/scenario -d '{"scenario":"low_confidence"}'
```

Irrigation scenarios: `normal`, `low_moisture`, `pump_running`,
`sensor_failure` (null temperature/humidity, matching a DHT11 read
failure), `malformed` (invalid JSON, to exercise error handling).

Vision scenarios: `no_result` (fresh boot), `healthy`,
`disease_detected`, `low_confidence` (returns Spider_Mite at 0.40
confidence -- the real model's documented weak point, not an optimistic
placeholder; see [`docs/dataset.md`](dataset.md)).

## Automated integration test

`mobile_app/test/esp32_simulator_integration_test.dart` runs the real
`Esp32Service` (`lib/services/esp32_service.dart`, completely
unmodified) against the real simulator classes over actual loopback
HTTP -- not a mocked `http.Client`, not a fake service. It's part of the
normal test suite:

```bash
cd mobile_app
flutter test test/esp32_simulator_integration_test.dart
```

This test is what caught a real bug: `fetchSensors()`/`fetchMode()`/
`fetchLatestVisionResult()` let a raw `FormatException` escape on a
malformed response instead of the `Esp32Exception` type the rest of the
class (and the UI's error display) expects -- confirmed to matter
because `sensor_dashboard_screen.dart` interpolates the caught error
directly into user-facing text. Fixed in
`lib/services/esp32_service.dart` by wrapping each decode in a
try/catch that raises a consistent `Esp32Exception` instead.
