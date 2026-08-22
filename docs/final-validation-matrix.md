# Final validation matrix

Every row below reflects real, actually-observed evidence — see the
linked doc for the full account of each. Nothing here is upgraded past
what was genuinely executed and observed.

**Status legend**
- **PASS** — actually executed/deployed/observed for real, not mocked or simulated
- **SIMULATED** — verified against a real stand-in (simulator, mock, or virtual environment) that matches the real contract, not the real thing itself
- **BLOCKED** — a required external resource (physical hardware, a device) is genuinely unavailable
- **NOT SUPPORTED** — the tool/service itself cannot do this, regardless of effort

| Component | Status | Evidence | Limitation |
|---|---|---|---|
| Irrigation firmware compilation | PASS | Compiled in CI (`arduino-cli`) against real ESP32 board definitions on every push — [`firmware-compile.yml`](../.github/workflows/firmware-compile.yml) | None — compile-time only, says nothing about hardware runtime behavior |
| Vision firmware compilation | PASS | Same workflow, `esp32:esp32:esp32cam` board target | Same as above |
| Firmware host-side logic tests | PASS | `g++`-compiled real execution of pump state machine, thresholds, RGB565 decode, INT8 quantize/dequantize — [`docs/host-testing.md`](host-testing.md) | Hardware-independent logic only; no ESP32 I/O, timing, or peripherals involved |
| Wokwi simulation — local | PASS | Real firmware boots, real ESP32 boot ROM output captured, deterministic `WOKWI_IRRIGATION_READY` marker detected via `wokwi-cli --expect-text`, exit code 0. Root-caused a real missing serial-monitor config after two earlier inconclusive attempts — [`docs/wokwi-simulation.md`](wokwi-simulation.md) | Validates boot/Serial/GPIO only — not real relay/pump electrical behavior, real soil sensor accuracy, or real hardware timing |
| Wokwi simulation — GitHub Actions | PASS | Real triggered run, monitored to completion: [run `32560846142`](https://github.com/FURYBALA/smart-agriculture-system/actions/runs/32560846142), `success`, real compile + real simulation + marker detected on a clean `ubuntu-latest` runner | Same scope limits as local Wokwi, above |
| ESP32-CAM camera/vision simulation | NOT SUPPORTED | Checked directly against Wokwi's parts registry (`wokwi-cli lint`, and Wokwi's documented parts catalog) — no camera/image-sensor component exists at all | Not a limitation of this project's effort; Wokwi itself has no such component. Never attempted or claimed |
| Physical ESP32 hardware bring-up | BLOCKED | — | No physical board available in this development environment |
| Physical ESP32-CAM hardware bring-up | BLOCKED | — | No physical board available in this development environment |
| ML model training | PASS | Real CNN trained from scratch on 3,200 PlantVillage images, 81.9% float validation accuracy — [`docs/dataset.md`](dataset.md) | Held-out PlantVillage images only, not real garden photos |
| ML model quantization | PASS | Real post-training INT8 quantization, 69.9 KB `.tflite`, 65.8% quantized spot-check accuracy on 240 held-out images, 99.2% float-vs-quantized prediction agreement confirming quantization wasn't the cause of an earlier apparent regression | Same PlantVillage-only caveat as above |
| ML pipeline consistency (class labels, quantization params) | PASS | Cross-checked directly across `training_metadata.json`, firmware `class_labels.h`, and backend `CLASS_LABELS` — identical, not assumed | — |
| ML real-world / field accuracy | NOT TESTED | — | No real garden photos evaluated; PlantVillage's cropped, plain-background images don't represent field conditions |
| Backend Lambda handler tests | PASS | 19 real `pytest` tests against real handler code, `moto`-mocked S3/SQS/DynamoDB — [`docs/backend-local-testing.md`](backend-local-testing.md) | AWS itself is mocked in this suite (real AWS is covered separately below) |
| Backend real-model inference (local) | PASS | Real `ai-edge-litert` interpreter loading the actual shipped `.tflite` model, run against a synthetic test image | Synthetic image, not a real diseased-leaf photo |
| SAM template validation | PASS | `sam validate --lint` — clean | — |
| SAM container build | PASS | `sam build --use-container`, real Docker, full stack including `InferenceHandlerFunction` — confirmed in CI logs | — |
| AWS deployment | PASS | Real `sam deploy` via manual GitHub Actions workflow, stack `smart-agriculture-system`, `ap-south-1`, all 21 resources `CREATE_COMPLETE`/`UPDATE_COMPLETE` — [`backend/README.md`](../backend/README.md#deployed-instance) | Deployment isn't auto-kept-in-sync with future code changes; re-run to update |
| AWS diagnosis end-to-end | PASS | Real image → `POST /diagnose` → S3 → SQS → real Lambda inference (actual trained model) → DynamoDB → polled `GET /diagnose/{id}` → `complete` with real class + confidence. Independently confirmed directly in DynamoDB (`get-item`) and S3 (`s3 ls`) | — |
| AWS chat API | PASS | Real `POST`/`GET /chat/{sessionId}` round-tripped through DynamoDB against the live API | — |
| AWS IAM policy scoping | PASS | Every Lambda's policy is resource-scoped by name (`S3CrudPolicy`, `DynamoDBCrudPolicy`, `SQSPollerPolicy` bound to specific resources) — verified directly by reading `template.yaml`, no wildcards found | Tight-scoping confirmed by design; a separate denied-access enforcement probe was not run |
| AWS deployment workflow safety | PASS | `workflow_dispatch`-only, confirmed no `push`/`pull_request` trigger exists; credentials only via GitHub encrypted secrets, never printed | — |
| Flutter static analysis | PASS | `flutter analyze` — 0 issues | — |
| Flutter unit/integration tests | PASS | `flutter test` — 19/19 passing, including a real integration test against a protocol-accurate ESP32 simulator | — |
| Flutter web build | PASS | `flutter build web` — succeeds in CI and locally | Compile-time only, by itself — see web runtime row below |
| Flutter web runtime | PASS | Real, isolated headless Chromium (Playwright) actually loaded the built app and was driven through all 6 screens by real clicks — 0 uncaught exceptions. Found and fixed a real bug (History screen's database didn't work on web at all) — [`docs/flutter-runtime.md`](flutter-runtime.md) | A populated diagnosis/history list was never observed (no data was saved through the real UI in this pass) |
| Android release APK build | PASS | `flutter build apk --release` — real, verified 20.7 MB installable APK, after fixing a real Gradle 7→8/Kotlin/JDK 21 toolchain mismatch | — |
| Android/iOS physical or emulated runtime | BLOCKED | — | No physical device or emulator available in this development environment |
| Firmware/Flutter/Backend CI workflows | PASS | 4 GitHub Actions workflows (firmware compile, Flutter, backend, Wokwi simulation), all green on the current `main` HEAD | — |
| Security — credential handling | PASS | Full git history scanned for `.env` files or AWS/Wokwi/Gemini key-shaped strings — none found, ever committed. Secrets referenced only via `${{ secrets.X }}`, masked automatically in all logs | — |
| Security — deploy workflow hardening | PASS | Found and fixed a real anti-pattern (a secret interpolated directly into shell script text instead of passed via `env:`) — low practical risk, fixed correctly regardless | — |
| Documentation accuracy | PASS | Repository-wide sweep for stale "not deployed"/"pending"/"predicted, not observed" claims from before the AWS deployment and browser-runtime work — found and corrected across `README.md`, `docs/DEPLOYMENT.md`, `docs/bring-up-checklist.md`, `docs/differences-from-report.md` | — |
