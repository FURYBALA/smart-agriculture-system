# Final release status

The single source of truth for what's actually verified in this
project, as of commit `93c6b52` and this release audit. Every row uses
exactly one of these categories — none are upgraded past what was
genuinely observed:

- **PASS** — actually executed/deployed/observed for real
- **IMPLEMENTED** — real, working code exists; not independently
  re-verified as part of this specific audit pass (distinct from
  "untested" — it may have been verified earlier, just not re-checked
  now)
- **SIMULATED** — verified against a real stand-in that matches the
  actual contract, not the real thing itself
- **BLOCKED** — a required external resource (hardware, a device) is
  genuinely unavailable
- **NOT SUPPORTED** — the tool/service itself cannot do this, regardless of effort
- **INCONCLUSIVE** — attempted for real, but the result doesn't
  establish a clear pass or fail

| Component | Status | Evidence | What was tested | What was not tested |
|---|---|---|---|---|
| Irrigation firmware — compiles | PASS | CI, `arduino-cli` against real `esp32:esp32:esp32` board defs, every push | Compile-time correctness against a real toolchain | Runtime behavior on a real board |
| Vision firmware — compiles | PASS | CI, `esp32:esp32:esp32cam` board target | Same as above | Same as above |
| Irrigation firmware — logic | PASS | `g++`-compiled real execution, `firmware/test/test_irrigation_logic.cpp` | Pump state machine, soil ADC conversion, cooldown, safety cutoff | Real GPIO/relay/sensor I/O |
| Vision firmware — logic | PASS | `g++`-compiled real execution, `firmware/test/test_vision_logic.cpp` | RGB565 decode, INT8 quantize/dequantize, argmax | Real camera capture, real TFLite Micro execution on-device |
| Irrigation node — Wokwi (local) | PASS | Real firmware boots, `WOKWI_IRRIGATION_READY` detected, exit code 0, run multiple times | Boot sequence, Serial output, diagram wiring | Relay/pump electrical behavior, real sensor accuracy, real timing |
| Irrigation node — Wokwi (GitHub Actions) | PASS | [Run `32560846142`](https://github.com/FURYBALA/smart-agriculture-system/actions/runs/32560846142), `success`, clean `ubuntu-latest` runner | Same as above, independently reproduced off the local machine | Same limits as above |
| Vision node — Wokwi camera simulation | NOT SUPPORTED | Checked directly against Wokwi's parts registry — no camera/image-sensor component exists | N/A — never attempted, since the capability doesn't exist | Camera capture, on-device inference in simulation |
| Physical ESP32 (irrigation) | BLOCKED | — | — | Everything requiring real hardware: sensor accuracy, relay wiring, real timing, real Wi-Fi behavior |
| Physical ESP32-CAM (vision) | BLOCKED | — | — | Everything requiring real hardware: camera image quality, real inference timing/power, real Wi-Fi behavior |
| ML model — training | PASS | Real CNN trained from scratch, 81.9% float validation accuracy on 3,200 PlantVillage images | Training pipeline, held-out validation split | Real-world/field image accuracy |
| ML model — INT8 quantization | PASS | Real post-training quantization, 69.9 KB `.tflite`, 65.8% quantized spot-check accuracy, 99.2% float-vs-quantized agreement | Quantization correctness, accuracy-gap root cause | Real-world accuracy (same caveat as above) |
| ML pipeline consistency | PASS | Class labels and quantization params cross-checked directly across firmware/backend/training metadata | Cross-component consistency | — |
| ML real-world accuracy | INCONCLUSIVE | No real garden photos evaluated | — | Cannot be marked BLOCKED (no external resource is missing — real photos could be sourced) or PASS (never measured); genuinely open |
| Backend — Lambda handler tests | PASS | 19 real `pytest` tests, real handler code, `moto`-mocked AWS | Request validation, error handling, DynamoDB serialization, S3/SQS interaction shape | Real AWS service behavior (covered separately below) |
| Backend — real model inference (local) | PASS | Real `ai-edge-litert` interpreter, actual shipped `.tflite` file, synthetic test image | Full preprocess→invoke→postprocess pipeline | Prediction correctness on a real diseased leaf |
| SAM template | PASS | `sam validate --lint` clean; `sam build --use-container` succeeds in CI (real Docker) | Template correctness, buildability | — |
| AWS deployment | PASS | Real `sam deploy`, stack `smart-agriculture-system`, `ap-south-1`, 21/21 resources `CREATE_COMPLETE`/`UPDATE_COMPLETE`, confirmed via read-only `describe-stacks` as part of this audit | Full deployment lifecycle | Long-term operational behavior (this is a point-in-time deployment, not a monitored production service) |
| AWS diagnosis end-to-end | PASS | Real image → S3 → SQS → real Lambda inference → DynamoDB → polled `complete`. Independently confirmed via direct `get-item`/`s3 ls`, not just the API's own response | The complete async pipeline, for real | Prediction correctness on a real diseased leaf (same as local inference) |
| AWS chat API | PASS | Real `POST`/`GET /chat/{sessionId}` round-tripped through DynamoDB | Request/response contract, persistence | — |
| AWS IAM scoping | PASS | Every Lambda's policy resource-scoped by name, verified by reading `template.yaml` directly — no wildcards | Policy design | Real denied-access enforcement probe (not attempted — would require intentionally trying an unauthorized action) |
| AWS deploy workflow safety | PASS | Confirmed `workflow_dispatch`-only, no `push`/`pull_request` trigger | Trigger configuration | — |
| Flutter — static analysis | PASS | `flutter analyze`, 0 issues | Code quality/lint rules | — |
| Flutter — unit/integration tests | PASS | `flutter test`, 19/19, including real integration test against a protocol-accurate ESP32 simulator | Widget rendering, service logic, simulator-backed integration | Real device I/O |
| Flutter — web build | PASS | `flutter build web` succeeds, CI and local | Compile-time correctness | Runtime behavior (covered separately below) |
| Flutter — web runtime | PASS | Real, isolated headless Chromium (Playwright), all 6 screens clicked through, 0 uncaught exceptions | Real browser rendering and navigation, a real bug found and fixed (History/`sqflite` on web) | A populated diagnosis/history list (no data was saved through the real UI in this pass) |
| Android — release APK build | PASS | Real 20.7 MB APK, after fixing a real Gradle/Kotlin/JDK toolchain mismatch | Build toolchain correctness | Runtime behavior on a device |
| Android/iOS — physical or emulated runtime | BLOCKED | — | — | Everything requiring a real or emulated device |
| CI workflows | PASS | 4 automatic + 1 manual-deploy + 1 manual-Wokwi workflow, all green on current `main` | Every workflow's actual execution | — |
| Security — credential handling | PASS | Full git history scanned for `.env`/key-shaped strings — none found; secrets referenced only via `${{ secrets.X }}`, auto-masked in logs | Credential storage and reference patterns | Penetration testing / active abuse simulation (not attempted, out of scope) |
| Security — workflow hardening | PASS | Found and fixed a real anti-pattern (secret interpolated into shell text instead of `env:`) | Workflow secret-handling patterns | — |
| Documentation accuracy | PASS | Repository-wide sweep for stale "not deployed"/"inconclusive"/"untested" claims, corrected across README, DEPLOYMENT.md, template.yaml comments, and others | Internal consistency across all `.md` files and key code comments | — |

## The four limitations that are not going away without external resources

**Physical ESP32:**
BLOCKED — no hardware.

**Physical ESP32-CAM:**
BLOCKED — no hardware.

**Android/iOS physical/emulator:**
BLOCKED — no device/emulator.

**ESP32-CAM Wokwi camera simulation:**
NOT SUPPORTED — no camera/image-sensor component in Wokwi.

These four are stated identically everywhere in this repository's
documentation. None of them is described as PASS, IMPLEMENTED, or
SIMULATED anywhere.
