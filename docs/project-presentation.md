# Project presentation — talking points by length and topic

Every claim below is backed by something real and verifiable elsewhere
in this repository — see [`docs/final-validation-matrix.md`](final-validation-matrix.md)
for the underlying evidence behind each. Nothing here should be said in
a way that implies more than what's actually been done.

## A. 30-second explanation

"I built a smart agriculture system that combines IoT sensors with AI.
Two ESP32 microcontrollers — one handles automatic soil-moisture
irrigation, the other runs an on-device machine learning model that
detects tomato leaf diseases from a camera. Both connect to a Flutter
app I built, and I also deployed a serverless AWS backend as an
alternative cloud inference path. Everything's tested — real unit
tests, real integration tests, a real AWS deployment I verified
end-to-end, and a real circuit simulation in CI since I didn't have
physical hardware available."

## B. 1-minute explanation

"It's a two-part system. The irrigation side is a plain ESP32 reading
a soil moisture sensor and a DHT11 for temperature/humidity, driving a
relay-controlled pump automatically, with a safety cutoff timer so it
can't run forever if something goes wrong. The vision side is an
ESP32-CAM running a custom convolutional neural network — I trained it
from scratch, quantized it to INT8 so it fits in about 70 KB, and it
classifies 8 tomato leaf conditions on-device with TensorFlow Lite
Micro.

Both nodes expose a REST API that a Flutter app I built talks to over
local Wi-Fi — sensor dashboard, irrigation controls, disease diagnosis,
history, even a plant-care chatbot. For diagnosis specifically, the app
also has a cloud path: I deployed a full serverless AWS backend — API
Gateway, Lambda, S3, SQS, DynamoDB — as an alternative to calling
Gemini Vision directly, and I've actually run real images through it
end-to-end.

I didn't have physical ESP32 hardware or a mobile device during
development, so I built real test infrastructure instead: host-side
unit tests for the firmware logic, a protocol-accurate simulator for
the mobile app to talk to, and I got Wokwi's circuit simulator actually
booting the real firmware — which took real debugging to get working,
not just assuming it would."

## C. 2-minute explanation

Start with B, then add:

"A few things I think are worth highlighting technically. First, the
ML pipeline — I didn't just train a model and stop. Quantized accuracy
initially looked much worse than the float model, an 18-point drop,
and instead of assuming that was just quantization loss, I compared
float and quantized predictions image-by-image and found 99.2%
agreement — so quantization wasn't the cause. The real problem was a
biased evaluation sample. Fixing that surfaced two genuinely weak
classes, and I improved them by rebalancing training data — a real,
measured improvement, documented alongside two other approaches I
tried that actually made things worse.

Second, the AWS deployment wasn't just `sam deploy` and done — I found
and fixed a real bug where the Lambda Layer's Python path was getting
double-nested by SAM's build process, which is the kind of bug that's
invisible to any local test because it only happens during the actual
build-and-package step.

Third, on the simulation side — Wokwi's CLI kept connecting but
producing zero serial output, across multiple attempts, which looked
like an environment problem. I proved it wasn't by testing Wokwi's own
official example project first — it worked immediately — which let me
diff configs and find the actual cause: a missing serial-monitor
connection in my diagram file. That's now fixed and passing, both
locally and in GitHub Actions."

## D. 5-minute technical explanation

Use B + C, then walk through architecture, ML, AWS, and testing (E–L
below) selectively based on what the audience asks about, rather than
reciting all of them — that's what makes it feel like understanding
rather than a memorized script.

## E. Architecture explanation

Three independent layers, loosely coupled:

1. **Firmware layer** (two ESP32 nodes): irrigation node runs a closed
   control loop (read sensors → decide → actuate pump) and exposes
   `GET /sensors`, `GET/POST /mode`, `POST /pump/on|off`. Vision node
   captures a frame, runs on-device inference, exposes `GET /latest`.
   Neither node depends on the other or on the cloud — irrigation
   keeps working with no internet at all.
2. **Mobile layer** (Flutter): talks to both nodes over local Wi-Fi via
   plain HTTP/REST, and separately to Gemini Vision (for diagnosis) and
   Gemini text (for chat) directly from the phone. `Provider` for state,
   `sqflite` for local history (with a web-specific persistence path
   added when `sqflite`'s lack of a browser implementation was found
   and fixed).
3. **Cloud layer** (AWS, optional): an alternative diagnosis path —
   `API Gateway → S3 (image) → SQS → Lambda (inference) → DynamoDB
   (result) ← poll`. Async by design: the upload returns immediately;
   inference happens in a separately-scaled function.

The mobile app is the only thing that talks to all three layers; the
three layers never talk to each other.

## F. ML explanation

- Custom CNN, ~61K parameters, 4 conv blocks + global average pooling,
  trained from scratch (no transfer learning) in Keras on 3,200
  PlantVillage images (400/class, 8 classes)
- 81.9% float validation accuracy; post-training INT8 quantization to
  a 69.9 KB `.tflite` file for TFLite Micro on the ESP32-CAM
- 65.8% quantized spot-check accuracy on 240 held-out images — the
  ~16-point gap from float was investigated, not shrugged off: a
  99.2% float-vs-quantized prediction agreement ruled out quantization
  itself as the cause; the real cause was a biased evaluation sample
- The two weakest classes (Spider Mite, Target Spot — both were near
  chance-level initially) improved to 40.0%/43.3% after doubling their
  training data; confusion-matrix analysis shows both overlap visually
  with Septoria Leaf Spot specifically, which looks like a genuine
  feature-resolution limit of this model size, not a fixable bug
- The exact same `.tflite` file is used both on-device (TFLite Micro)
  and in the AWS Lambda (`ai-edge-litert`), so there's one source of
  truth for the model, not two copies that could drift

## G. AWS explanation

- API Gateway (REST) → 4 Lambda functions (Python 3.12) → S3 (image
  storage, 90-day lifecycle expiry) + SQS (inference queue) + DynamoDB
  (2 tables: diagnosis results, chat history)
- Defined as infrastructure-as-code (AWS SAM `template.yaml`), not
  clicked together — every resource is reproducible from source
- Each Lambda's IAM policy is scoped to only the specific
  bucket/queue/table it needs (`S3CrudPolicy`, `DynamoDBCrudPolicy`,
  `SQSPollerPolicy` bound to specific resource names) — no wildcard
  permissions
- Deployed via a manual-only GitHub Actions workflow (never triggers
  automatically), with AWS credentials only ever referenced via GitHub
  encrypted secrets
- Actually deployed and verified end-to-end: real image → real S3
  object → real SQS message → real Lambda inference (the actual
  trained model, not a stub) → real DynamoDB write → polled and
  confirmed via the live API
- One real deployment-only bug found and fixed: SAM's Lambda Layer
  build step was double-nesting the shared code's Python path,
  something no local test could ever catch since local tests bypass
  SAM's actual build step entirely

## H. Flutter explanation

- 6 screens behind a bottom `NavigationBar`: Sensor Dashboard,
  Irrigation Control, Disease Diagnosis, History, Chatbot, Device
  Connectivity Tests
- `Provider` for dependency injection/state (ESP32 service, Gemini
  service, history database)
- Local persistence via `sqflite` on mobile; found during testing that
  it has zero web implementation (crashes outright), fixed by wiring
  `sqflite_common_ffi_web` in behind a `kIsWeb` check — mobile code
  path unchanged
- Tested three ways: `flutter analyze`/`flutter test` in CI (19 tests,
  including a real integration test against a protocol-accurate ESP32
  simulator), a real release APK build (20.7 MB, after fixing a real
  Gradle/Kotlin/JDK version mismatch), and a real headless-Chromium
  (Playwright) run that actually loaded the built web app and clicked
  through all 6 screens

## I. ESP32 explanation

- Irrigation node (plain ESP32): DHT11 (temp/humidity), analog soil
  moisture sensor, relay-driven pump on a GPIO, `WebServer`-based REST
  API. Auto mode has a hard safety cutoff timer, tracked by *who*
  started the pump (auto vs. manual) rather than current mode — a real
  bug found and fixed, since gating on current mode alone would let a
  mid-cycle mode switch silently disable the safety cutoff
- Vision node (ESP32-CAM): captures a frame, decodes RGB565 (the
  camera driver emits it big-endian — a real byte-order bug found and
  fixed), preprocesses and quantizes to INT8, runs the same trained
  model via TensorFlow Lite Micro, serves the latest result over REST.
  The tensor arena (~250 KB) overflowed the ESP32's internal DRAM once
  Wi-Fi/WebServer buffers were counted — fixed by allocating it in
  PSRAM instead
- Both compile-checked against real ESP32 board definitions in CI on
  every push; hardware-independent logic (pump state machine,
  thresholds, RGB565 decode, INT8 quantize/dequantize) is extracted
  into plain headers and unit-tested with `g++` — no board needed

## J. Wokwi explanation

- Wokwi is a browser/CLI-based circuit simulator — it can boot real
  compiled ESP32 firmware in a simulated CPU and simulate simple
  peripherals (a DHT sensor, a potentiometer standing in for the soil
  sensor, an LED standing in for the relay)
- Real, non-trivial debugging story: two config bugs were found and
  fixed early (wrong pin-naming convention, a required-but-missing
  `wokwi.toml` field), then the simulation connected successfully but
  produced zero serial output — across the real firmware *and* an
  independently-written trivial sanity sketch, which looked like an
  environment problem
- It wasn't. Testing against Wokwi's own official example project
  proved the CLI/network/token all worked, which let me diff configs
  and find the actual cause: the diagram never wired the board's UART
  to a serial monitor. Fixed, and now passing deterministically — both
  locally and independently in GitHub Actions on a clean Ubuntu runner
- Explicitly **not** claimed: Wokwi has no camera/image-sensor
  simulation component at all, so the vision node's actual camera
  capture and inference path was never attempted in simulation — said
  plainly rather than implied to work

## K. Testing explanation

- **Firmware**: pure logic (pump state machine, thresholds, RGB565
  decode, quantize/dequantize) extracted into headers, host-tested with
  `g++` — no board needed. Both sketches also real-compiled against
  actual ESP32 board definitions in CI on every push
- **Backend**: 19 `pytest` tests against real Lambda handler code, with
  `moto`-mocked S3/SQS/DynamoDB — including real model inference
  through the actual shipped `.tflite` file, not a stub
- **Mobile**: 19 Flutter tests (`flutter test`), including a real
  integration test against a hand-built local server that serves the
  exact same JSON contract as the real firmware
- **Wokwi**: real circuit simulation, both locally and in CI, described
  in J above
- **AWS**: real end-to-end smoke tests against the live deployed API —
  not mocked, not simulated
- **Explicitly not claimed as tested**: physical ESP32/ESP32-CAM
  hardware behavior, and running on a physical or emulated mobile
  device — both genuinely unavailable in this development environment,
  and never described otherwise anywhere in this repository

## L. Limitations explanation

Said plainly, not hidden:

- No physical ESP32 or ESP32-CAM hardware was available, so neither
  node has actually been flashed or bring-up tested — firmware
  compiling cleanly and its logic passing host tests are real, but
  real-hardware behavior (sensor accuracy, relay wiring, camera
  quality, Wi-Fi timing) is not verified
- No physical or emulated mobile device was available — the web
  runtime is real and verified (headless Chromium), but a native
  Android/iOS install-and-launch has not happened
- Wokwi cannot simulate a camera at all, so the vision node's actual
  capture-and-inference path has no simulation coverage, only host-side
  logic tests
- The ML model's real-world accuracy is unmeasured — PlantVillage's
  cropped, plain-background images don't represent a real garden photo
  with clutter and variable lighting; expect a real accuracy drop until
  fine-tuned on real deployment images
