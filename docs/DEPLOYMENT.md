# Smart Agriculture System Setup

This is the single, start-from-zero runbook for taking this repository
from a fresh clone to a fully running system: two flashed ESP32 boards,
a deployed AWS backend (optional), and the Flutter app installed on a
phone. Every other doc in `docs/` covers one piece in more depth; this
one is the order to actually do it in.

Read [**Section 0**](#0-what-this-repo-has-verified-vs-what-it-hasnt)
first if you only read one section — it sets expectations for what
"done" means at each step.

## 0. What this repo has verified vs. what it hasn't

Four different claims get made throughout this document, and they mean
different things:

| Label | Means |
|---|---|
| **CI VALIDATION** | Compiled/built/tested automatically on every push to this repo — real, repeatable, checkable in the Actions tab |
| **LOCAL TESTING** | Run once, by hand, in this project's development environment (no physical hardware, device, or AWS account) |
| **SIMULATED TESTING** | Run against a stand-in (the local ESP32 REST simulator, `moto`-mocked AWS) that matches the real contract but isn't the real thing |
| **PHYSICAL VALIDATION** | Actually run on real ESP32 hardware, a real phone/emulator, or a deployed AWS stack — **this is the status that is still pending everywhere in this document** |

Nothing in this repository claims physical validation. Every step below
says explicitly which of the first three categories it's backed by.

## Prerequisites

- Two ESP32 boards: a plain ESP32 dev board (irrigation node) and an
  ESP32-CAM, AI-Thinker variant (vision node)
- DHT11 sensor, a resistive/capacitive soil moisture sensor, a
  single-channel relay module, a 5V water pump — see
  [`wiring.md`](wiring.md) for exact pins
- Arduino IDE or `arduino-cli`, with the `esp32` board package and the
  libraries listed in [`bring-up-checklist.md`](bring-up-checklist.md)
- Flutter SDK 3.22+, and either an Android device/emulator or iOS
  device/simulator with its platform toolchain installed
- A Gemini API key ([aistudio.google.com/apikey](https://aistudio.google.com/apikey)) --
  required for the app's primary (cloud) diagnosis path and chatbot
- *(Optional)* An AWS account with configured credentials, Docker, and
  `aws-sam-cli` -- only needed if you want the self-hosted backend path
  instead of / alongside Gemini-direct
- *(Optional)* A [Wokwi](https://wokwi.com) account/token -- only
  needed to run the irrigation node's simulation config

## 1. Clone repository

```bash
git clone https://github.com/FURYBALA/smart-agriculture-system.git
cd smart-agriculture-system
```

## 2. Configure secrets

Nothing here is committed to git -- every secret has an example
template with a placeholder. See **Security** (step 15 below) for the
full list of what's checked.

```bash
cd mobile_app
cp .env.example .env
# edit .env: fill in GEMINI_API_KEY, and (once you know them) the
# IRRIGATION_NODE_HOST / VISION_NODE_HOST IPs printed by each board's
# Serial output in step 5
cd ..
```

If you're also deploying the AWS backend, credentials go through the
AWS CLI's normal mechanism (`aws configure`), never into a repo file --
see step 6.

## 3. Configure ESP32 irrigation node

Edit `firmware/irrigation_node/config.h`:

```c
#define WIFI_SSID     "your-wifi-ssid"
#define WIFI_PASSWORD "your-wifi-password"
```

Everything else in that file (pins, thresholds, timing) already matches
this project's documented hardware -- see
[`wiring.md`](wiring.md) for what to physically connect, and
calibrate `SOIL_RAW_DRY`/`SOIL_RAW_WET` per your specific sensor unit
per [`bring-up-checklist.md`](bring-up-checklist.md) (every unit reads
differently; the shipped values are placeholders, not calibrated for
any specific sensor).

## 4. Configure ESP32-CAM

Edit `firmware/vision_node/config.h`:

```c
#define WIFI_SSID     "your-wifi-ssid"
#define WIFI_PASSWORD "your-wifi-password"
```

`model_data.h` and `class_labels.h` are already generated from the
shipped, trained model -- don't hand-edit them; regenerate via
`ml/scripts/convert_tflite.py` only if you retrain.

## 5. Build and flash firmware

**Status: CI VALIDATION (compiles) + LOCAL TESTING (logic) — not PHYSICAL VALIDATION.**
Full procedure: [`bring-up-checklist.md`](bring-up-checklist.md).

```bash
# Irrigation node
arduino-cli compile --fqbn esp32:esp32:esp32 firmware/irrigation_node
arduino-cli upload -p <PORT> --fqbn esp32:esp32:esp32 firmware/irrigation_node

# Vision node (PSRAM must be enabled in board settings)
arduino-cli compile --fqbn esp32:esp32:esp32cam firmware/vision_node
arduino-cli upload -p <PORT> --fqbn esp32:esp32:esp32cam firmware/vision_node
```

Open Serial Monitor at 115200 baud on each board after flashing --
both print their IP address once Wi-Fi connects. Write those IPs down;
they go into `mobile_app/.env` in step 7.

## 6. Deploy AWS backend (optional)

Skip this entirely if you're using the app's default Gemini-direct
diagnosis path. Full procedure with all commands:
[`backend/README.md`](../backend/README.md).

**Status: AWS DEPLOYMENT VALIDATION.** This backend has actually been
deployed and exercised against real AWS — not just built.

### Deployed instance

| | |
|---|---|
| Account / region | `273422285791` / `ap-south-1` |
| Stack | `smart-agriculture-system` (`UPDATE_COMPLETE`, 21/21 resources `CREATE_COMPLETE`) |
| Deployed via | [`.github/workflows/deploy-aws.yml`](../.github/workflows/deploy-aws.yml), a manual-only (`workflow_dispatch`) GitHub Actions workflow — chosen specifically because GitHub's runners have Docker and this project's local dev machine doesn't, and `sam build --use-container` needs it for the model-inference function's native dependencies |
| API base URL | `https://p17huf2s49.execute-api.ap-south-1.amazonaws.com/prod/` |
| Verified | `POST /diagnose` (synthetic test image) → real S3 object → real SQS message → real `ai-edge-litert` inference against the actual shipped model → real DynamoDB write → polled to `complete` via `GET /diagnose/{id}`. `POST`/`GET /chat/{sessionId}` verified the same way. CloudWatch logs checked clean (no errors) across all four functions. |

One real deployment bug was found and fixed along the way: the Lambda
Layer's Python module wasn't importable
(`No module named 'common'`) due to a `python/` prefix being applied
twice — once already present in the source, once added by SAM's build
step. Confirmed by downloading and inspecting the actual deployed layer
zip, not guessed. Fixed by moving the source up one level; see
[`backend/README.md`](../backend/README.md#deployed-instance) for the
full explanation. This is exactly the class of bug that can only
surface from a real deployment — every local/CI test bypasses SAM's
actual layer-build step by adding the source directly to `sys.path`.

**What this does NOT prove:** anything about the ESP32 firmware's REST
calls actually reaching this API (the firmware doesn't call this
backend at all — see the architecture diagram), or the app's UI layer
(the mobile app's primary diagnosis path calls Gemini Vision directly
and has no code wired to this backend's URL today, unchanged by this
deployment). This deployment also isn't kept continuously in sync with
future commits — it reflects the code as of commit `d10504a`.

Short version to deploy your own copy:

```bash
cp ml/models/tomato_disease_model_int8.tflite backend/lambda_functions/inference_handler/
cd backend/infrastructure
aws configure
sam build --use-container
sam deploy --guided
# note the ApiUrl from the deploy output or:
aws cloudformation describe-stacks --stack-name <stack-name> \
  --query "Stacks[0].Outputs[?OutputKey=='ApiUrl'].OutputValue" --output text
```

## 7. Configure Flutter app

Back in `mobile_app/.env`, fill in the values gathered above:

```
GEMINI_API_KEY=<from aistudio.google.com>
IRRIGATION_NODE_HOST=<IP from step 5's Serial output>
VISION_NODE_HOST=<IP from step 5's Serial output>
```

If you deployed the AWS backend in step 6 and want the app to use it,
that requires adding a `BACKEND_API_URL` call site to
`lib/services/` -- the current app's primary diagnosis path calls
Gemini directly and doesn't read a backend URL from `.env` today; see
[`backend/README.md`](../backend/README.md)'s "Why this exists
alongside Gemini Vision" for that architectural choice.

No physical ESP32 yet? Point the host variables at the local simulator
instead and skip straight to step 12:
```
IRRIGATION_NODE_HOST=127.0.0.1:8090
VISION_NODE_HOST=127.0.0.1:8091
```
See [`simulation.md`](simulation.md).

## 8. Build/install mobile app

**Status: CI VALIDATION (analyze/test/web build) — not PHYSICAL/EMULATOR VALIDATION.**

```bash
cd mobile_app
flutter pub get
flutter analyze
flutter test
flutter run                    # debug, connected device/emulator
# or:
flutter build apk --release    # -> build/app/outputs/flutter-apk/app-release.apk
```
See [`mobile_app/README.md`](../mobile_app/README.md) for the full
build/install procedure, including iOS.

## 9. Verify ESP32 APIs

**Status: PHYSICAL VALIDATION — pending hardware.**

```bash
curl http://<irrigation-node-ip>/sensors
curl http://<vision-node-ip>/latest
```
Expected shapes are documented in each firmware file's header comment
and exactly mirrored by the local simulator
(`mobile_app/tool/esp32_simulator_lib.dart`) if you want to see the
expected response shape without hardware first.

## 10. Verify ML inference

**Status: LOCAL TESTING (real model, real interpreter, synthetic test image) — real accuracy is `docs/dataset.md`'s domain, not this step.**

```bash
cd backend
pip install -r requirements-dev.txt
python -m pytest tests/test_lambda_handlers_local.py -v -k RealInference
```
This loads the actual shipped `.tflite` model via `ai-edge-litert` and
runs real inference end-to-end. See
[`backend-local-testing.md`](backend-local-testing.md) for exactly
what this does and doesn't prove.

## 11. Verify backend

**Status: CI VALIDATION + SIMULATED TESTING — not deployed.**

```bash
cd backend
python -m pytest tests/ -v          # 19 tests against moto-mocked AWS
cd infrastructure && sam validate --lint && sam build --use-container
```

If you completed step 6 (real deployment), also run the `curl` smoke
test in [`backend/README.md`](../backend/README.md)'s "Deploying"
section against your real `ApiUrl` — that step is genuinely PHYSICAL
VALIDATION once you've done it.

## 12. Verify mobile application

**Status: CI VALIDATION + SIMULATED TESTING (against the local ESP32 simulator) — not PHYSICAL/EMULATOR VALIDATION.**

```bash
cd mobile_app
dart run tool/esp32_simulator.dart &     # in one terminal
flutter test test/esp32_simulator_integration_test.dart
```
This runs the real, unmodified `Esp32Service` against a local server
matching the real firmware's exact contract.

## 13. End-to-end test

See [`end-to-end-test-plan.md`](end-to-end-test-plan.md) for the full
test matrix (hardware, vision, mobile, backend, and combined flows),
with every currently-BLOCKED test marked as such rather than guessed
at.

## 14. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Pump runs immediately on boot | Relay board is active-LOW (most low-cost ones are) | Flip `RELAY_ACTIVE_LOW` in `irrigation_node/config.h` |
| Soil moisture % doesn't match reality | Sensor uncalibrated | Watch raw `analogRead()` Serial output at fully dry/wet, set `SOIL_RAW_DRY`/`SOIL_RAW_WET` |
| Vision node halts at boot with "Model setup failed" | PSRAM not enabled in board settings | Enable PSRAM; partition scheme "Huge APP (3MB No OTA/1MB SPIFFS)" |
| `sam build` fails on `ai-edge-litert` | Building without `--use-container` (native binary needs a Lambda-matching container) | Use `sam build --use-container` |
| App can't reach ESP32 | Phone and boards not on the same Wi-Fi network, or `.env` IPs stale (DHCP reassigned) | Re-check each board's Serial output for its current IP |
| Malformed/garbled device response in the app | This was a real, fixed bug (`Esp32Service` used to leak a raw parser exception) | Confirm you're on a commit at or after the fix — see root README's engineering-work list |

## 15. Security

- Real secrets never live in tracked files: `mobile_app/.env` is
  gitignored (only `.env.example` with placeholders is tracked); AWS
  credentials go through the AWS CLI's own credential store; Wi-Fi
  credentials in firmware `config.h` files are placeholder strings in
  the repo, edited locally before flashing (step 3/4), never committed
  with real values.
- Verify before ever pushing a commit:
  ```bash
  git status              # .env should not appear
  git ls-files | grep -i "\.env$"   # should print nothing
  ```
- If you deploy the AWS backend, the S3 bucket has a 90-day image
  auto-expiry lifecycle rule, and each Lambda function's IAM policy is
  scoped narrowly (SAM policy templates) to only the specific
  bucket/queue/table it needs — not a shared broad role.
- If you ever build a public Flutter **web** deployment (not currently
  done, and not recommended as-is): `mobile_app/.env` is bundled as a
  static web asset, meaning the Gemini API key would be extractable
  from the client bundle. Route Gemini calls through a backend proxy
  first if you ever actually deploy a public web build — see
  [`flutter-runtime.md`](flutter-runtime.md).
