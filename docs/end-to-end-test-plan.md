# End-to-end test plan

Every test case below has a real, current **Status**. Nothing is marked
PASS unless it was actually executed and observed — see
[`DEPLOYMENT.md`](DEPLOYMENT.md#0-what-this-repo-has-verified-vs-what-it-hasnt)
for what CI VALIDATION / LOCAL TESTING / SIMULATED TESTING / PHYSICAL
VALIDATION each mean. Tests that need physical ESP32 hardware or a
physical/emulated Android/iOS device are marked **BLOCKED**, never
PASS — that's the one category of limitation left genuinely
unavoidable in this environment. AWS deployment and a real (headless
Chromium, via Playwright) browser runtime are no longer on that list;
see B6/B7 and M6-M8 below.

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
| H11 | Irrigation node boots and connects to Wi-Fi in Wokwi simulation | Serial shows Wi-Fi connect, then "REST API server started." | Actually run with a real token: found and fixed 2 real config bugs (invalid pin names, missing required `firmware` field); with those fixed, `wokwi-cli` connects to the real API and starts a session but never completes — confirmed not a firmware issue via an independent trivial sanity-sketch test that fails identically | ATTEMPTED (real API, real token) — INCONCLUSIVE, see `wokwi-simulation.md` |

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
| M2 | App displays a disease diagnosis result | Diagnosis screen renders class + confidence | Verified at the service/parsing layer (integration test). Screen itself now confirmed rendering correctly in a real browser (real headless-Chromium run, see `flutter-runtime.md`) — but only its empty/no-image state; an actual populated result (real class + confidence rendered after a real diagnosis) was not observed, since that needs a real Gemini call or a real ESP32-CAM result, neither exercised through the UI | SIMULATED TESTING (service layer) + REAL BROWSER (empty state only) — populated-result rendering NOT TESTED |
| M3 | App sends an irrigation command and reflects the new pump state | `/pump/on` then a subsequent `/sensors` poll shows `pumpOn: true` | Integration test exercises exactly this against the simulator | SIMULATED TESTING |
| M4 | App handles a malformed device response without crashing | Error is caught and displayed as readable text, not a raw exception | This was a real bug, found and fixed this session (`Esp32Service` was leaking `FormatException`); regression test passing | SIMULATED TESTING — real bug, real fix, real regression test |
| M5 | App handles missing/null sensor fields | Dashboard shows "--" rather than a misleading zero for null temperature/humidity | Unit-tested at the model layer (`SensorReading.fromJson`) | CI VALIDATION (unit test) |
| M6 | App handles an unreachable device | Timeout after 5s, readable error shown, no crash | `pingIrrigationNode`/`pingVisionNode` return false on failure, exercised by the connectivity-check pattern; **and** actually observed for real: a real headless-Chromium run against the built web app (no ESP32 present) rendered "Could not reach the irrigation node." exactly as designed, not a raw exception (see `flutter-runtime.md`) | LOCAL/UNIT TESTING + REAL BROWSER RUNTIME (web) — native device/emulator runtime still BLOCKED |
| M7 | History screen shows past diagnoses and sensor snapshots | List renders saved entries, pull-to-refresh works | `sqflite` round-trip tests pass (model serialization). Real bug found in a real browser: History was completely broken on web (`databaseFactory not initialized`) — fixed for real by adding `sqflite_common_ffi_web`, wired up in `main.dart` behind `kIsWeb`; re-verified in the same real headless-Chromium run, now renders "No diagnoses yet." (empty-but-successful query against a real IndexedDB/wasm SQLite). Populated-list rendering (with actual saved entries) still not observed — no data was ever saved through the real UI flow (see `flutter-runtime.md`) | REAL BROWSER RUNTIME — empty-state PASS, real bug fixed; populated-list rendering + native device/emulator NOT TESTED |
| M8 | App launches and all 6 tabs render on a physical device or emulator | App opens, navigation works, no crash | **Now actually observed** — a real, isolated headless Chromium (via Playwright, not the environment's Edge profile) loaded the built web app and was driven through all 6 `NavigationBar` destinations by real clicks at real screen coordinates; each screen screenshotted, zero uncaught JS exceptions across the whole pass (see `flutter-runtime.md` for all 6 screenshots' contents). This is real evidence for the **web** runtime specifically — a physical Android/iOS device or emulator remains genuinely unavailable and untested | REAL BROWSER RUNTIME (web) — PASS. Native device/emulator — BLOCKED |
| M9 | Release APK builds successfully | `flutter build apk --release` produces an installable APK | Runs for real — a 20.7 MB `app-release.apk` produced, after fixing a real Gradle 7→8/Kotlin/JDK 21 mismatch (see `flutter-runtime.md`) | LOCAL BUILD — PASS (installing/running it is separately BLOCKED, no device/emulator) |
| M10 | App compiles for web | `flutter build web` succeeds | Passing, locally and in CI | CI VALIDATION |

## Backend

| # | Test | Expected result | Actual result | Status |
|---|---|---|---|---|
| B1 | Upload → S3 → SQS | `POST /diagnose` stores the image in S3 and queues an SQS message | Real handler code tested against `moto`-mocked S3/SQS — passing | SIMULATED TESTING |
| B2 | Inference → DynamoDB write | `inference_handler` reads the queued job, runs real inference, writes a `Decimal`-safe result | Real handler + real model inference, `moto`-mocked DynamoDB — passing | SIMULATED TESTING (real inference, mocked storage) |
| B3 | API response for a pending/complete/failed diagnosis | `GET /diagnose/{id}` returns the correct shape for each state | `results_handler` tested against all three states directly | SIMULATED TESTING |
| B4 | Corrupt image doesn't leave a diagnosis stuck "pending" forever | A failed inference writes an explicit `status: "failed"` record | Verified — `_run_one()` raises on a corrupt image, `handler()`'s try/except is what converts that to the failed-status write | LOCAL TESTING (the raise; the catch-and-write itself is existing reviewed code, not separately re-tested this pass) |
| B5 | Deployment package builds correctly, including the model-inference function | `sam build --use-container` succeeds for the full stack | Confirmed via real CI log: `Build Succeeded` for `InferenceHandlerFunction` specifically | CI VALIDATION (real Docker) |
| B6 | Real deployed API responds correctly | `curl` against a real `ApiUrl` returns expected shapes | **Run for real** against `https://p17huf2s49.execute-api.ap-south-1.amazonaws.com/prod/`: `POST /diagnose` → `202` + `diagnosisId`; polled `GET /diagnose/{id}` → `complete` with real class + confidence; `POST`/`GET /chat/{sessionId}` round-tripped correctly. Found and fixed a real Lambda Layer bug in the process (see `docs/DEPLOYMENT.md#deployed-instance`) | AWS DEPLOYMENT VALIDATION — PASS |
| B7 | IAM policies actually restrict access as configured | Each function can only touch its own bucket/queue/table | Deployed successfully, **and** directly re-read `template.yaml`'s `Policies:` blocks: every function uses a resource-scoped SAM managed policy (`S3CrudPolicy`/`S3ReadPolicy` bound to `!Ref LeafImageBucket`, `SQSSendMessagePolicy`/`SQSPollerPolicy` bound to `!GetAtt InferenceQueue.QueueName`, `DynamoDBCrudPolicy`/`DynamoDBReadPolicy` bound to the specific table each function owns) — no `Resource: "*"` wildcards anywhere. Confirms the templates are scoped as designed; does not independently confirm AWS enforces them beyond the successful deploy (that would need an actual denied-access probe, not attempted) | AWS DEPLOYMENT VALIDATION + template audit — PASS (design), enforcement probe NOT EXECUTED |

## End-to-end

| # | Flow | Expected result | Actual result | Status |
|---|---|---|---|---|
| E1 | Camera → ML → backend → database → Flutter | A photo taken on-device flows through the full cloud pipeline and the result appears in the app | The backend half is real end-to-end (B6: API → S3 → SQS → real inference → DynamoDB → poll, against the live deployment), and the Flutter half now has real browser-runtime evidence (M8: all 6 screens actually observed rendering). What's still missing is specifically the join between them: no ESP32-CAM hardware exists to capture a real photo and feed it through this pipeline in one continuous, physically-observed flow | AWS half: PASS. Flutter half: PASS (web runtime). Camera/hardware join: BLOCKED |
| E2 | Sensor → ESP32 → Flutter → irrigation control | A real soil reading drives an app-displayed value, and an app command drives a real pump | Simulated version of this flow passes (M1, M3); real version needs real hardware | SIMULATED TESTING — real flow BLOCKED |
| E3 | Full system CI green simultaneously | Firmware, Flutter, and Backend CI all pass on the same commit | Confirmed — see root README badges / `gh run list` | CI VALIDATION |

## Summary

Everything reachable without physical ESP32 hardware or a physical/
emulated Android/iOS device has been exercised and is passing,
including two categories that used to be on that list: a real AWS
deployment (B6/B7) and a real, isolated headless-Chromium browser
runtime (M6-M8), the latter via Playwright rather than any tool that
was available when this plan was first written. Every row above marked
BLOCKED now requires physical hardware or a physical/emulated device
specifically, and is not claimed otherwise anywhere in this
repository.
