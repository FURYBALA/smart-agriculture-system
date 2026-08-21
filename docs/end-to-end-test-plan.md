# End-to-end test plan

Every test case below has a real, current **Status**. Nothing is marked
PASS unless it was actually executed and observed — see
[`DEPLOYMENT.md`](DEPLOYMENT.md#0-what-this-repo-has-verified-vs-what-it-hasnt)
for what CI VALIDATION / LOCAL TESTING / SIMULATED TESTING / PHYSICAL
VALIDATION each mean. Tests that need hardware, a device/emulator, or
an AWS account are marked **BLOCKED**, never PASS.

## Hardware

| # | Test | Expected result | Actual result | Status |
|---|---|---|---|---|
| H1 | Irrigation ESP32 boots and connects to Wi-Fi | Serial prints connecting dots then an IP address | — | BLOCKED — hardware required |
| H2 | Soil moisture sensor reports a plausible percentage | `GET /sensors` returns `soilMoisture` in [0,100], varies with actual moisture | — | BLOCKED — hardware required |
| H3 | DHT11 reports temperature/humidity | `GET /sensors` returns non-null `temperature`/`humidity` under normal conditions | — | BLOCKED — hardware required |
| H4 | DHT11 read failure reports null, not garbage | `GET /sensors` returns explicit JSON `null` (not 0 or NaN) if the sensor read fails | Logic verified via host test (`convertSoilRawToPercent`, threshold functions) — real sensor failure mode unobserved | LOCAL/HOST TESTING ONLY — real failure mode BLOCKED |
| H5 | Pump activates in AUTO mode below the dry threshold | Relay switches, pump runs | — | BLOCKED — hardware required |
| H6 | Pump stops above the wet threshold | Relay switches off | — | BLOCKED — hardware required |
| H7 | Pump auto-cutoff timer stops a long-running AUTO cycle | Pump switches off after `PUMP_RUN_MS` regardless of soil reading | Decision logic verified by host test (`shouldAutoCutoff`) — real timing/relay response unobserved | LOCAL/HOST TESTING ONLY — real timing BLOCKED |
| H8 | Manual pump override is never cut off by the safety timer | Pump started via `/pump/on` keeps running past `PUMP_RUN_MS` until explicit `/pump/off` | Host test asserts this exact property (`pumpStartedByAuto` tracking) — CI VALIDATION | LOGIC VERIFIED — real relay behavior BLOCKED |
| H9 | Cooldown prevents back-to-back waterings | A second AUTO start attempt within `PUMP_COOLDOWN_MS` of the last finish is refused | Host test (`canStartPump`) — CI VALIDATION | LOGIC VERIFIED — real timing BLOCKED |
| H10 | ESP32-CAM captures a frame | `esp_camera_fb_get()` returns a valid framebuffer | — | BLOCKED — hardware required |

## Vision

| # | Test | Expected result | Actual result | Status |
|---|---|---|---|---|
| V1 | RGB565 frame decodes to correct RGB values | Pure red/white/black test patterns decode to their expected normalized channel values | Host test (`decodeRgb565BigEndian`) passing in CI against synthetic pixel patterns | CI VALIDATION |
| V2 | Preprocessing quantizes correctly against the shipped model's real scale/zero-point | INT8 output lands in [-128,127], boundary values near the expected extremes | Host test (firmware) + backend `_preprocess()` test against real `training_metadata.json` values — both passing | CI VALIDATION + LOCAL TESTING |
| V3 | Real model inference runs end-to-end | Interpreter loads, `invoke()` succeeds, returns a valid class index + confidence | `ai-edge-litert` loads the real `.tflite` model and runs it on a synthetic test image via `pytest` | LOCAL TESTING (real model, synthetic image — not a real leaf photo) |
| V4 | Input/output tensor shapes match documented metadata | `(1,96,96,3)` int8 input, `(1,8)` int8 output, quantization matching `training_metadata.json` exactly | Confirmed directly against the live interpreter | LOCAL TESTING |
| V5 | Classification on a real diseased leaf photo | A correct or at-least-plausible disease class with reasonable confidence | Not run — no real leaf photo available in this environment (dataset dir is gitignored, not present locally) | BLOCKED — real image + ideally hardware required |
| V6 | Camera → model → REST response, physically end-to-end | `GET /latest` reflects a just-captured real frame's classification | — | BLOCKED — hardware required |
| V7 | Confidence values are stable/sane across repeated captures of the same static scene | Similar confidence across consecutive frames of an unchanging subject | — | BLOCKED — hardware required |

## Mobile

| # | Test | Expected result | Actual result | Status |
|---|---|---|---|---|
| M1 | App connects to (simulated) ESP32 and displays sensor readings | Sensor Dashboard shows temperature/humidity/soil moisture from the simulator | `flutter test test/esp32_simulator_integration_test.dart` passing — real `Esp32Service` against the real simulator | SIMULATED TESTING |
| M2 | App displays a disease diagnosis result | Diagnosis screen renders class + confidence | Verified at the service/parsing layer (integration test); screen-level rendering not observed in a running app | SIMULATED TESTING (service layer only) — screen rendering BLOCKED |
| M3 | App sends an irrigation command and reflects the new pump state | `/pump/on` then a subsequent `/sensors` poll shows `pumpOn: true` | Integration test exercises exactly this against the simulator | SIMULATED TESTING |
| M4 | App handles a malformed device response without crashing | Error is caught and displayed as readable text, not a raw exception | This was a real bug, found and fixed this session (`Esp32Service` was leaking `FormatException`); regression test passing | SIMULATED TESTING — real bug, real fix, real regression test |
| M5 | App handles missing/null sensor fields | Dashboard shows "--" rather than a misleading zero for null temperature/humidity | Unit-tested at the model layer (`SensorReading.fromJson`) | CI VALIDATION (unit test) |
| M6 | App handles an unreachable device | Timeout after 5s, readable error shown, no crash | `pingIrrigationNode`/`pingVisionNode` return false on failure; exercised by the connectivity-check pattern, not observed against a truly offline device in a running app | LOCAL/UNIT TESTING — full runtime behavior BLOCKED |
| M7 | History screen shows past diagnoses and sensor snapshots | List renders saved entries, pull-to-refresh works | `sqflite` round-trip tests pass (model serialization); full screen render on a device/emulator not observed | CI VALIDATION (data layer only) — screen rendering BLOCKED |
| M8 | App launches and all 6 tabs render on a physical device or emulator | App opens, navigation works, no crash | Widget smoke test confirms the shell builds in a test harness; never launched on a real device, emulator, or observed in a browser (a headless-browser attempt did not produce an isolated render — see `flutter-runtime.md`) | BLOCKED — device/emulator/observable browser required |
| M9 | Release APK builds successfully | `flutter build apk --release` produces an installable APK | Not run in this environment (incomplete Android SDK — missing `cmdline-tools`, licenses) | BLOCKED — complete Android SDK required |
| M10 | App compiles for web | `flutter build web` succeeds | Passing, locally and in CI | CI VALIDATION |

## Backend

| # | Test | Expected result | Actual result | Status |
|---|---|---|---|---|
| B1 | Upload → S3 → SQS | `POST /diagnose` stores the image in S3 and queues an SQS message | Real handler code tested against `moto`-mocked S3/SQS — passing | SIMULATED TESTING |
| B2 | Inference → DynamoDB write | `inference_handler` reads the queued job, runs real inference, writes a `Decimal`-safe result | Real handler + real model inference, `moto`-mocked DynamoDB — passing | SIMULATED TESTING (real inference, mocked storage) |
| B3 | API response for a pending/complete/failed diagnosis | `GET /diagnose/{id}` returns the correct shape for each state | `results_handler` tested against all three states directly | SIMULATED TESTING |
| B4 | Corrupt image doesn't leave a diagnosis stuck "pending" forever | A failed inference writes an explicit `status: "failed"` record | Verified — `_run_one()` raises on a corrupt image, `handler()`'s try/except is what converts that to the failed-status write | LOCAL TESTING (the raise; the catch-and-write itself is existing reviewed code, not separately re-tested this pass) |
| B5 | Deployment package builds correctly, including the model-inference function | `sam build --use-container` succeeds for the full stack | Confirmed via real CI log: `Build Succeeded` for `InferenceHandlerFunction` specifically | CI VALIDATION (real Docker) |
| B6 | Real deployed API responds correctly | `curl` against a real `ApiUrl` returns expected shapes | Not run — no AWS account/credentials available | BLOCKED — AWS account required |
| B7 | IAM policies actually restrict access as configured | Each function can only touch its own bucket/queue/table | SAM policy templates configured; not verified against real AWS IAM behavior | BLOCKED — real AWS deployment required |

## End-to-end

| # | Flow | Expected result | Actual result | Status |
|---|---|---|---|---|
| E1 | Camera → ML → backend → database → Flutter | A photo taken on-device flows through the full cloud pipeline and the result appears in the app | Each hop verified independently (V3/V4, B1–B4, M1–M4); never observed as one continuous physical flow | BLOCKED — hardware + device + AWS deployment all required together |
| E2 | Sensor → ESP32 → Flutter → irrigation control | A real soil reading drives an app-displayed value, and an app command drives a real pump | Simulated version of this flow passes (M1, M3); real version needs real hardware | SIMULATED TESTING — real flow BLOCKED |
| E3 | Full system CI green simultaneously | Firmware, Flutter, and Backend CI all pass on the same commit | Confirmed — see root README badges / `gh run list` | CI VALIDATION |

## Summary

Everything reachable without physical ESP32 hardware, a mobile
device/emulator/observable browser, or an AWS account has been
exercised and is passing. Every row above marked BLOCKED requires one
of those three resources and is not claimed otherwise anywhere in this
repository.
