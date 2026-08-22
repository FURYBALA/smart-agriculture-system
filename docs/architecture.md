# Architecture

This is the authoritative architecture reference — one diagram, one
data-flow narrative, and an explicit verification-status tag on every
link in the chain. See [`docs/final-release-status.md`](final-release-status.md)
for the full evidence behind each tag.

## System diagram

```
┌─────────────────────┐        ┌──────────────────────────┐
│  Irrigation Node     │        │  Vision Node (ESP32-CAM) │
│  (plain ESP32)       │        │                           │
│                       │        │  Camera → RGB565 decode  │
│  DHT11 + soil ADC     │        │  → INT8 quantize →       │
│  → decision logic     │        │  TFLite Micro inference  │
│  → relay/pump         │        │  → latest result cache   │
│                       │        │                           │
│  REST: /sensors       │        │  REST: /latest            │
│  /mode /pump/on|off   │        │                           │
└──────────┬───────────┘        └───────────┬──────────────┘
           │  Wi-Fi / REST (same local network)          │
           └───────────────────┬─────────────────────────┘
                                │
                     ┌──────────▼───────────┐
                     │   Flutter Application  │
                     │  6 screens, Provider    │
                     │  state management       │
                     └───┬──────────────┬─────┘
                         │              │
             photo diagnosis      optional cloud path
             (default: direct)          │
                         │              │
                 ┌───────▼──────┐  ┌────▼─────────────────┐
                 │ Gemini Vision │  │   AWS API Gateway     │
                 │ (phone→cloud) │  │  (deployed, ap-south-1)│
                 └───────────────┘  └────┬──────────────────┘
                                          │
                          ┌───────────────┼──────────────────┐
                          │               │                  │
                    ┌─────▼─────┐   ┌─────▼──────┐    ┌──────▼──────┐
                    │  Upload    │   │  Results    │    │    Chat      │
                    │  Lambda    │   │  Lambda     │    │   Lambda     │
                    └──┬─────┬──┘   └──────┬──────┘    └──────┬──────┘
                       │     │              │                  │
                 ┌─────▼─┐ ┌─▼───┐   ┌──────▼──────┐    ┌──────▼──────┐
                 │  S3   │ │ SQS │   │DiagnosisResults│  │ ChatHistory │
                 │(image)│ │queue│   │  (DynamoDB)    │  │ (DynamoDB)  │
                 └───────┘ └──┬──┘   └──────▲──────┘    └─────────────┘
                               │              │
                        ┌──────▼──────────────┴───┐
                        │   Inference Lambda        │
                        │   (real INT8 TFLite model, │
                        │    ai-edge-litert)         │
                        └────────────────────────────┘
```

## Data flow, with verification status on every link

| # | Link | Status | Evidence |
|---|---|---|---|
| 1 | Irrigation Node ↔ real DHT11/soil sensor/relay | **BLOCKED — physically validated** | No hardware available; firmware logic is host-tested, hardware behavior is not |
| 2 | Irrigation Node ↔ Wokwi (virtual DHT/potentiometer/LED) | **SIMULATED — PASS** | Real firmware boots and runs in Wokwi, locally and in GitHub Actions ([run `32560846142`](https://github.com/FURYBALA/smart-agriculture-system/actions/runs/32560846142)) |
| 3 | Vision Node ↔ real camera/ESP32-CAM hardware | **BLOCKED — physically validated** | No hardware available |
| 4 | Vision Node ↔ Wokwi | **NOT SUPPORTED** | Wokwi has no camera/image-sensor simulation component at all — not attempted |
| 5 | Irrigation/Vision Node → Flutter app (REST over Wi-Fi) | **SIMULATED — PASS** (protocol) / **BLOCKED** (physical) | A hand-built local simulator serves the identical JSON contract; the real, unmodified app code was tested against it in a real integration test. Never tested against a physical node |
| 6 | Flutter app → Gemini Vision/text | **IMPLEMENTED, not independently re-verified this pass** | Real SDK integration exists in code (`gemini_service.dart`); calling it requires a user-supplied API key, not exercised as part of this repo's own CI |
| 7 | Flutter app → AWS API Gateway | **CLOUD-VALIDATED — PASS** | Real `curl` calls against the live deployed API, verified end-to-end (see rows 8-11) |
| 8 | API Gateway → Upload Lambda → S3 + SQS | **CLOUD-VALIDATED — PASS** | Real image uploaded, confirmed present in S3 via `aws s3 ls` |
| 9 | SQS → Inference Lambda → real INT8 model → DynamoDB | **CLOUD-VALIDATED — PASS** | Real inference ran in the deployed Lambda (confirmed via CloudWatch logs showing the TFLite XNNPACK delegate initializing); result confirmed directly in DynamoDB via `get-item` |
| 10 | API Gateway → Results Lambda → poll response | **CLOUD-VALIDATED — PASS** | Polled `GET /diagnose/{id}` returned `complete` with a real class + confidence |
| 11 | API Gateway → Chat Lambda → DynamoDB | **CLOUD-VALIDATED — PASS** | Real `POST`/`GET /chat/{sessionId}` round-tripped |
| 12 | Flutter app on a real/emulated device | **BLOCKED — physically validated** | No device/emulator available |
| 13 | Flutter app in a real browser | **PHYSICALLY-EQUIVALENT — PASS** | A real, isolated headless Chromium (Playwright) loaded the built app and clicked through all 6 screens — this is real browser execution, just not a phone |

## Where the ESP32-CAM vision node actually fits

The vision node is architecturally independent of both the irrigation
node and the AWS backend — it's a third, self-contained device with
its own responsibility:

1. Captures a 96×96 frame from the onboard camera
2. Decodes RGB565 (big-endian, per the camera driver — see
   [`docs/technical-deep-dive.md`](technical-deep-dive.md) for the
   exact byte-order bug this project found and fixed here)
3. Quantizes to INT8 and runs the same trained model on-device via
   TensorFlow Lite Micro (arena allocated in PSRAM)
4. Caches the latest classification result and serves it over
   `GET /latest`

It does **not** stream video to the app (the original report's plan;
found unreliable and deliberately not attempted here — see
[`docs/differences-from-report.md`](differences-from-report.md)), and
it does **not** call the AWS backend or Gemini — those are the
Flutter app's job, using its own separately-captured image. The vision
node's on-device result is a free, offline-capable *alternative* to
cloud diagnosis, polled by the app's "Use on-device ESP32-CAM result
instead" button — not a step in the cloud pipeline.

## Why the cloud path is optional, not primary

The Flutter app's default diagnosis flow calls Gemini Vision directly
from the phone and needs no backend at all. The AWS pipeline exists to
match the original project report's architecture diagram (a
first-party model behind a first-party API, not a third-party vision
API) and to demonstrate the pattern for real — it is a genuine,
independently-deployed and independently-tested alternative path, not
a stub or an unused diagram.

## Implemented vs. simulated vs. cloud-validated vs. physically validated — summary

- **Implemented**: every component listed above has real, working
  source code — this is not a design document for something unbuilt
- **Simulated**: irrigation node boot/logic (Wokwi, both locally and
  in CI) and the ESP32/vision REST contract (local Dart simulator)
- **Cloud-validated**: the entire AWS pipeline, end-to-end, against
  the live deployed account
- **Physically validated**: **nothing** — no physical ESP32, no
  physical ESP32-CAM, no physical/emulated mobile device was available
  in this development environment. Said plainly, not hedged.
