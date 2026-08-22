# Final interview preparation

50+ likely questions across 25 categories, grounded in this
repository's actual, verified work. For higher-stakes questions:
**Short answer** (one line), **Strong answer** (interview-length), a
**likely follow-up**, and its answer. Less pivotal questions get short
+ strong answers only.

## 1. Project overview

**Q1. What is this project?**
Short: A dual-node ESP32 IoT system for irrigation and plant disease
detection, unified in a Flutter app, with an optional deployed AWS
backend.
Strong: See [`docs/project-presentation.md`](project-presentation.md)'s
1-minute explanation.

**Q2. What problem does it solve?**
Short: Manual plant care — irrigation timing and disease identification
— both automated.
Strong: Overwatering/underwatering from manual guesswork, and late
disease detection from infrequent visual inspection, are both solvable
with cheap sensors and a small on-device model — this demonstrates
that at low cost (~$20 in hardware for the irrigation node) without
needing constant cloud connectivity.

## 2. Architecture

**Q3. Describe the high-level architecture.**
See [`docs/architecture.md`](architecture.md) — three independent
layers (firmware, mobile, optional cloud) that don't talk to each
other directly; the mobile app is the integration point.

**Q4. Why keep the layers independent instead of centralizing through
the cloud?**
Short: Resilience — irrigation shouldn't depend on internet
connectivity.
Strong: A centralized-through-cloud design means a Wi-Fi/ISP outage
stops your plants from being watered. Keeping irrigation as a closed
local loop (sensor → decision → actuator, no cloud round-trip) means
it keeps working regardless of internet state — the cloud is
additive (diagnosis, chat), not load-bearing for the core safety-
critical function.
*Follow-up: what if the ESP32 itself crashes?* — No explicit watchdog
timer is implemented currently; the ESP32's own hardware watchdog
provides a baseline safety net at the platform level, but an
application-level watchdog reset is a real, identified gap for
production use, not yet added.

## 3. Machine learning

**Q5. What kind of model is this?**
Short: A custom CNN, ~61K params, 4 conv blocks + global average
pooling, trained from scratch.
Strong: See [`docs/project-presentation.md`](project-presentation.md)
section F.

**Q6. Why train from scratch instead of transfer learning?**
Short: Size constraint — needs to fit in ~70 KB post-quantization for
an ESP32-CAM.
Strong: Standard transfer-learning backbones (MobileNet, EfficientNet)
are tens of megabytes even before quantization — far too large for
TFLite Micro's typical microcontroller RAM budget. A small
purpose-built architecture was the only realistic path to fitting on
this specific hardware.
*Follow-up: what did you give up by not using transfer learning?* —
Likely some accuracy ceiling, especially on the two weakest classes —
a pretrained backbone's learned low-level features (edges, textures)
might disambiguate visually similar diseases better than a from-
scratch model can learn from only 3,200 images.

## 4. TFLite

**Q7. Why TensorFlow Lite Micro specifically?**
Short: It's the standard, well-supported inference runtime for
microcontrollers without an OS.
Strong: It has no filesystem or dynamic-memory-heavy dependencies,
supports a static/pre-allocated arena (critical for predictable memory
use on a ~320 KB-DRAM chip), and has direct Arduino-ecosystem library
support for ESP32.

**Q8. Walk through the inference call itself.**
Short: `esp_camera_fb_get()` → `preprocessFrame()` → `interpreter->
Invoke()` → dequantize + argmax → cache result.
Strong: See [`docs/technical-deep-dive.md`](technical-deep-dive.md#vision-processing)
for the exact function-by-function walkthrough with real source
references.

## 5. INT8 quantization

**Q9. What is INT8 quantization and why use it here?**
Short: Representing weights/activations as 8-bit integers instead of
32-bit floats — ~4x smaller, faster on integer-only hardware.
Strong: The ESP32 has no hardware FPU acceleration comparable to a
modern CPU/GPU; INT8 arithmetic is both smaller (69.9 KB vs. what
would be a much larger float model) and faster on this hardware.
Quantization is post-training here (not quantization-aware training),
applied via TFLite's converter.

**Q10. Your quantized accuracy dropped noticeably from float. Explain.**
Short: Investigated directly — quantization wasn't actually the cause.
Strong: An ~18-point drop looked like a quantization problem at first.
Compared float vs. quantized predictions image-by-image instead of
assuming: 99.2% agreement, which rules quantization out as the cause.
The real issue was a biased evaluation sample (an alphabetically-
last-N slice of files, not randomly sampled) that happened to
overweight the two weakest classes.
*Follow-up: how did you find the biased sample?* — By checking what
the evaluation script's file-selection logic actually did versus what
was assumed — it took the last N files by sort order rather than a
random subset, which for this dataset's file-naming convention
correlated with class.

## 6. Dataset

**Q11. What dataset did you use?**
Short: PlantVillage, 3,200 images (400/class, 8 classes).
Strong: See [`docs/dataset.md`](dataset.md) for the exact source-class
mapping, including one documented substitution (Bacterial Speck →
Bacterial Spot, the closest available proxy in this subset).

**Q12. What are the limitations of this dataset for your use case?**
Short: Cropped, plain-background lab images, not real garden photos.
Strong: PlantVillage images are consistently lit, centered, and
background-free — real smartphone/camera captures in a garden have
clutter, variable lighting, and partial occlusion. Expect a real
accuracy drop until fine-tuned on actual deployment-condition images;
this is stated as an open limitation, not glossed over.

## 7. Model limitations

**Q13. Which classes perform worst and why?**
Short: Spider Mite (40.0%) and Target Spot (43.3%), both well below
the other six.
Strong: Confusion-matrix analysis shows both overlap visually with
Septoria Leaf Spot specifically, not with each other — reads as a
feature-resolution limit for a model this small rather than an easily
fixable data or training bug. Doubling their training data helped
(from near chance-level), but two further attempts — an imbalanced
oversample and class-weighted loss — both made results worse, and are
documented rather than discarded.

**Q14. What would you try next to close the gap?**
Short: Real-world data, and possibly a slightly larger model now that
PSRAM headroom is confirmed.
Strong: Targeted data collection specifically for the Spider Mite/
Septoria/Target Spot confusion triangle would likely help more than
generic dataset growth, since the confusion is class-specific, not
uniform.

## 8. ESP32

**Q15. Why plain ESP32 for irrigation vs. ESP32-CAM for vision?**
Short: Different requirements — vision needs a camera and much more
RAM (PSRAM).
Strong: The irrigation node has no need for a camera, and a plain
ESP32 is cheaper and simpler; the vision node's tensor arena alone
(~250 KB) requires PSRAM the plain ESP32 doesn't have.

**Q16. Describe a real bug you found in the irrigation firmware.**
Short: The safety-cutoff timer had a mode-switch race condition.
Strong: Gating the auto-shutoff timer on "current mode == AUTO" has a
hole — if a user switches to manual mid-cycle, the cutoff would
silently stop applying, and the pump could run indefinitely. Fixed by
tracking *who* started the pump (`pumpStartedByAuto`), not the current
mode, so an auto-started pump is always subject to the timer
regardless of later mode switches.

## 9. ESP32-CAM

**Q17. What's the tensor arena, and what went wrong with it?**
Short: The scratch memory TFLite Micro uses during inference; it
overflowed internal DRAM.
Strong: A ~250 KB static array for the arena, combined with WiFi/
WebServer's own static buffers, overflowed the ESP32's ~320 KB of
internal DRAM by about 186 KB — caught by the linker in CI, not
guessed at. Fixed by allocating the arena in PSRAM via
`heap_caps_malloc(kTensorArenaSize, MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT)`
instead of a static array.

**Q18. Describe the RGB565 bug.**
Short: A byte-order mismatch silently swapped color channels.
Strong: The ESP32 camera driver emits RGB565 pixels big-endian; a
naive `uint16_t*` cast on the little-endian Xtensa core byte-swaps
every pixel with no error or crash — colors would just come out wrong.
Fixed by explicitly combining the high and low bytes in the correct
order in `decodeRgb565BigEndian()`.

## 10. REST APIs

**Q19. What does the irrigation node's API look like?**
Short: `GET /sensors`, `GET/POST /mode`, `POST /pump/on`, `POST /pump/off`.
Strong: All JSON, with real input validation (missing body → 400,
invalid JSON → 400, invalid mode value → 400, pump commands outside
manual mode → 409) — not just happy-path handlers.

**Q20. Why REST instead of MQTT or WebSockets for the ESP32 nodes?**
Short: Simplicity — the app polls occasionally, doesn't need push or a
persistent connection.
Strong: The Flutter app's usage pattern (occasional dashboard checks,
occasional commands) doesn't need MQTT's pub/sub model or a persistent
WebSocket — a stateless REST poll is simpler to implement, test, and
reason about, at the cost of not being real-time push.

## 11. Flutter

**Q21. What state management did you use and why?**
Short: `Provider`.
Strong: Simple, well-understood dependency injection for a
moderate-complexity app — services (ESP32, Gemini, history database)
are provided at the app root and consumed via `context.read`/`watch`,
no need for the added complexity of Bloc/Riverpod for this scope.

**Q22. Describe the web-persistence bug you found and fixed.**
Short: `sqflite` has no browser implementation; History crashed
outright on web.
Strong: Found via a real, isolated headless-Chromium (Playwright) run
that actually loaded the built web app: History threw `databaseFactory
not initialized` instead of loading. Fixed by adding
`sqflite_common_ffi_web` and setting `databaseFactory` conditionally
behind `kIsWeb` in `main.dart` — zero changes needed to
`HistoryDatabase` itself, since it already used `sqflite`'s pluggable
top-level `openDatabase()`/`getDatabasesPath()` functions, which just
route through whichever factory is registered.
*Follow-up: does this fully fix History on web?* — The database layer,
yes — verified re-rendering "No diagnoses yet." instead of crashing.
A separate, related gap remains unfixed: `dart:io File` (used for
reading picked images before saving a diagnosis) also has no web
implementation — named as a known limitation, not silently fixed or
claimed working.

## 12. AWS Lambda

**Q23. Walk through the four Lambda functions.**
Short: Upload, Inference, Results, Chat — each single-responsibility.
Strong: `upload_handler` validates/stores the image and enqueues a
job; `inference_handler` (SQS-triggered) runs real INT8 inference and
writes the result; `results_handler` serves poll requests;
`chat_handler` handles the chatbot's message history. Each has its own
IAM policy scoped to only what it needs.

**Q24. Describe the DynamoDB `Decimal` bug.**
Short: `boto3` rejects native Python `float` for DynamoDB writes.
Strong: `boto3`'s `TypeSerializer` raises "Float types are not
supported" for a plain Python `float` — a pre-existing bug that made
every successful inference write fail. Fixed with
`Decimal(str(value))`, not `Decimal(float_value)` directly, to avoid
inheriting float's binary-representation artifacts (`Decimal(0.1) !=
Decimal("0.1")`).

## 13. API Gateway

**Q25. How is the API secured?**
Short: It isn't authenticated — a deliberate scope decision for a
project with no user accounts.
Strong: Open CORS (`AllowOrigin: '*'`), no API key or auth required —
appropriate given there's no login system anywhere in this project.
IAM least-privilege on the Lambda side limits blast radius if the
endpoint were abused, but there's no rate limiting or auth layer, and
that's an explicitly named gap for anything beyond a demo.

## 14. S3

**Q26. What's stored in S3 and how long does it live?**
Short: Uploaded leaf images, with a 90-day expiry lifecycle rule.
Strong: `smart-agri-leaf-images-<account-id>` bucket, one object per
diagnosis under `uploads/<diagnosisId>.<ext>`, with an
`ExpirationInDays: 90` lifecycle rule so old demo/test images don't
accumulate indefinitely — confirmed directly via `get-bucket-
lifecycle-configuration`, not assumed from the template alone.

## 15. SQS

**Q27. Why a queue between upload and inference instead of a direct
call?**
Short: Decouples request latency from inference latency, and scales
independently.
Strong: `upload_handler` returns as soon as the image is in S3 and the
job is queued — it doesn't wait for inference. `inference_handler`
scales based on queue depth. `VisibilityTimeout: 60` gives inference
enough time to complete before a message could be redelivered.

## 16. DynamoDB

**Q28. Describe the two tables' schemas.**
Short: `DiagnosisResults` (hash key `diagnosisId`), `ChatHistory` (hash
key `sessionId`, range key `timestamp`).
Strong: Both `PAY_PER_REQUEST` billing (no capacity planning needed
for this scale). `ChatHistory`'s composite key lets a single query
retrieve a session's full message history in timestamp order.

## 17. CloudWatch

**Q29. How did you debug the production Lambda Layer bug?**
Short: Real CloudWatch logs, then downloaded and inspected the actual
deployed artifact.
Strong: CloudWatch showed `Runtime.ImportModuleError: No module named
'common'`. Rather than guess, downloaded the actual deployed Lambda
Layer zip and found `python/python/common.py` — doubly nested. Root
cause: the layer's source already had the required `python/`
subfolder, but SAM's `BuildMethod: python3.12` metadata made the
builder add *another* `python/` prefix during build. Fixed by moving
the source up one level so the builder's own prefixing produces the
correct path.

## 18. CI/CD

**Q30. What does your CI setup look like?**
Short: 4 GitHub Actions workflows — firmware, Flutter, backend, Wokwi
simulation — plus a manual-only AWS deploy workflow.
Strong: Firmware compiles against real ESP32 board defs and runs
host-side logic tests; Flutter runs `analyze`/`test`/`build web`;
backend runs `pytest` plus a real `sam build --use-container`; Wokwi
runs a real circuit simulation with a deterministic pass/fail check.
The AWS deploy and Wokwi-simulation workflows are `workflow_dispatch`-
only, deliberately, since one creates billable resources and the other
touches a third-party service.

**Q31. Describe a CI-only bug you found.**
Short: `moto`'s AWS mocking became unreliable once real AWS
credentials were also present in the environment.
Strong: After adding real AWS credentials to the deploy workflow,
previously-passing `moto`-mocked tests started hitting real
`ResourceNotFoundException` errors instead of the mock. Fixed by
reordering the workflow to run tests *before* configuring real
credentials, rather than trying to make the mock coexist with real
creds in the same process.

## 19. Wokwi

**Q32. What is Wokwi and what does it actually verify here?**
Short: A circuit/firmware simulator; verifies boot/Serial/GPIO
behavior for the irrigation node.
Strong: See [`docs/wokwi-simulation.md`](wokwi-simulation.md) for the
full root-cause story.

**Q33. Describe the debugging process that got Wokwi working.**
Short: Two earlier attempts stalled with zero serial output; diffing
against Wokwi's own official example project found the real cause.
Strong: The stall looked like an environment/service issue since it
reproduced even with a trivial, independently-written sanity sketch.
Cloning Wokwi's own official `esp-idf-hello-world` example and running
it unmodified worked immediately — proving the CLI/network/token were
fine — which let me diff configs and find the actual cause: the
diagram never wired the board's UART to a serial monitor. Fixed, and
confirmed passing deterministically, both locally and independently
in GitHub Actions.
*Follow-up: why didn't the trivial sanity sketch catch this?* — It
used the same class of hand-written diagram, which had the identical
missing-wiring gap — ruling out *that sketch's code* isn't the same as
ruling out a config assumption shared by every diagram written for the
investigation. A known-good external reference broke the deadlock,
not another self-written test.

## 20. Security

**Q34. How are secrets handled across this project?**
Short: GitHub encrypted secrets only, referenced via `${{ secrets.X }}`,
never printed or committed.
Strong: AWS keys, region, and the Wokwi CI token are all repo secrets.
Full git history was scanned for `.env` files or key-shaped strings —
none ever committed. One real hardening fix was made: an early
workflow version interpolated a secret directly into shell script text
instead of passing it via `env:` — a documented anti-pattern, fixed
properly even though the specific secret involved wasn't sensitive.

**Q35. What's the biggest security gap in this project as it stands?**
Short: No authentication on the public AWS API.
Strong: The API Gateway endpoint is open, unauthenticated,
wide-CORS — fine for a project with no user accounts and no sensitive
data, but a real gap if this were ever exposed to untrusted traffic at
scale. IAM least-privilege limits what a compromised function could
reach, but doesn't stop abuse of the API itself (e.g., cost-driving
spam requests).

## 21. Testing

**Q36. What's your overall test strategy?**
Short: Real code under test wherever possible, mocked only at the true
external boundary (AWS SDK calls, hardware I/O).
Strong: See [`docs/project-presentation.md`](project-presentation.md)
section K.

**Q37. How did you test firmware without hardware?**
Short: Extracted hardware-independent logic into plain headers,
host-tested with `g++`.
Strong: Pump state machine, thresholds, RGB565 decode, and INT8
quantize/dequantize all live in dependency-free headers
(`irrigation_logic.h`, `vision_logic.h`) with no Arduino/ESP32 includes
— real execution of real production logic via a plain host compiler,
separate from (and in addition to) full-sketch compile checks against
real board definitions.

## 22. Debugging

**Q38. Describe your general debugging approach on this project.**
Short: Reproduce with real evidence, form a specific hypothesis, test
it in isolation — not guess-and-check.
Strong: Concrete example: the quantization accuracy drop (Q10) could
have been "fixed" by just re-tuning quantization parameters and hoping
— instead, a targeted image-by-image comparison ruled out the
suspected cause first, which redirected the investigation to the
actual bug in one step instead of several rounds of guessing.

**Q39. What's a bug you found that surprised you?**
Short: The Wokwi zero-output stall being a missing diagram property,
not an environment issue.
Strong: See Q33 — the surprising part was that the "control"
experiment (a trivial sanity sketch) gave a false negative, because it
shared the same unexamined assumption as everything else being tested.

## 23. Deployment

**Q40. How is the AWS backend deployed?**
Short: `sam build --use-container` + `sam deploy` via a manual-only
GitHub Actions workflow.
Strong: The workflow never triggers automatically (`workflow_dispatch`
only), runs backend `pytest` before configuring real AWS credentials
(see Q31), then builds and deploys, then prints the resulting stack
outputs. AWS credentials are injected via `aws-actions/configure-aws-
credentials@v4` from GitHub secrets, never hardcoded.

**Q41. How do you know the deployment is healthy right now?**
Short: A read-only `describe-stacks` call.
Strong: `aws cloudformation describe-stacks --stack-name
smart-agriculture-system --region ap-south-1` — checked as part of
this very audit, returned `UPDATE_COMPLETE` with no destructive action
taken.

## 24. Trade-offs

**Q42. Gemini Vision (cloud, third-party) vs. your own AWS Lambda
inference — why have both?**
Short: Gemini is the simpler default; AWS is the self-hosted
alternative matching the original report's architecture.
Strong: Gemini needs zero infrastructure and is what the app actually
uses by default. The AWS path exists to prove the architecture in the
original report is real and demonstrable, not just diagrammed — a
deliberate choice to build both rather than only the easier one.

**Q43. On-device inference vs. cloud inference — which is better here?**
Short: Depends on the requirement — on-device is offline-capable and
free; cloud can run a model too large to fit on-device.
Strong: This project's on-device model and cloud model are literally
the same `.tflite` file, so the trade-off here isn't accuracy — it's
connectivity and latency. On-device works with zero internet; cloud
adds a network round-trip but could in principle run a larger model if
the on-device size constraint didn't apply.

## 25. Future improvements

**Q44. What's the single highest-value next step?**
Short: Real ESP32/ESP32-CAM hardware to close the two BLOCKED items.
Strong: Every other gap already has real evidence and real testing
behind it — hardware is the one thing no amount of additional software
work can substitute for.

**Q45. What would you add for production readiness?**
Short: Authentication on the API, an application-level watchdog on the
firmware, and real-world model fine-tuning.
Strong: See [`docs/interview-preparation.md`](interview-preparation.md)
Q29 for the fuller list.

**Q46. How would you scale the AWS backend for many more users?**
Short: It already scales automatically — Lambda/SQS/DynamoDB are all
serverless and elastic by default.
Strong: The real scaling question would shift to cost control (Lambda
invocation volume, S3 storage growth without the lifecycle rule) and
adding request-level rate limiting, not re-architecting the pipeline
itself.

**Q47. Would you change the ML architecture with more resources?**
Short: Possibly a slightly larger model, and/or knowledge distillation
from a larger teacher model.
Strong: More parameters risk not fitting the on-device size budget;
distillation could let a larger, more accurate model's knowledge
transfer into a still-small student model — untried here, a real
next step.

**Q48. What's a feature you deliberately left out?**
Short: Live MJPEG video streaming from the vision node to the app.
Strong: The original report's plan; found unreliable on this hardware
during earlier work and deliberately not pursued — polling a single
latest-classification result over REST is lighter and avoids the
bandwidth/latency problems streaming ran into. Documented as a
conscious scope decision, not a silently dropped feature.

**Q49. If a teammate joined tomorrow, what would you have them work
on first?**
Short: Physical hardware bring-up, using the existing bring-up
checklist.
Strong: [`docs/bring-up-checklist.md`](bring-up-checklist.md) is
already written for exactly this — flashing, wiring verification,
first-boot checks — so a new contributor with hardware in hand could
close the biggest remaining gap without needing to re-derive anything.

**Q50. How would you explain this project's biggest strength to a
skeptical interviewer?**
Short: Every claim is scoped to real evidence, including the
inconvenient findings.
Strong: The two "inconclusive, then root-caused" stories (ML
quantization, Wokwi) are the strongest evidence of engineering
discipline in this project — a weaker approach would have either
declared premature victory or given up and left it "blocked." Instead
both were driven to a real, verified conclusion through actual
investigation, and the false starts are documented rather than
erased.
