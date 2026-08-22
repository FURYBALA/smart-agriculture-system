# Interview preparation

Likely technical interview questions about this project, with concise,
honest answers grounded in what's actually in this repository. Answers
are intentionally short — expand verbally with specifics from
[`docs/project-presentation.md`](project-presentation.md) if asked to
elaborate.

## Architecture questions

**1. Walk me through the system architecture.**
Three independent layers: two ESP32 nodes (irrigation, vision) on
local Wi-Fi exposing REST APIs; a Flutter app that talks to both nodes
plus Gemini (vision + text) directly; and an optional AWS serverless
backend as an alternative diagnosis path. The layers don't talk to
each other — the mobile app is the only thing that touches all three.

*Follow-up: why isn't the AWS backend used by default?* — Because the
mobile app's primary diagnosis path (calling Gemini Vision directly
from the phone) is simpler and needs no backend infrastructure at all.
The AWS path exists to match the original project report's architecture
diagram and to demonstrate a self-hosted inference alternative — it's
optional by design, not a fallback that silently kicks in.

**2. Why two separate ESP32 nodes instead of one?**
Different jobs, different constraints. The vision node needs a camera
and a much larger tensor arena (PSRAM), which pushes toward an
ESP32-CAM specifically. The irrigation node is simpler and doesn't
need a camera at all. Splitting them also means irrigation keeps
working even if the vision node crashes or is unplugged.

**3. What happens if the internet goes down?**
Irrigation keeps working completely — it's a closed local loop
(sensor → decision → pump) with no cloud dependency. The vision node's
on-device inference also keeps working. Only the app's diagnosis-via-
Gemini and the optional AWS path need internet.

## ML questions

**4. Why a custom CNN instead of transfer learning?**
Fits the target: a tiny (69.9 KB after quantization) model that has to
run in TFLite Micro on an ESP32-CAM's limited RAM. A pretrained
backbone like MobileNet would be far larger even after quantization
and pruning.

**5. Your quantized accuracy is noticeably lower than float. Why?**
Investigated directly rather than assumed: compared float vs. quantized
predictions image-by-image and found 99.2% agreement, which rules out
quantization as the cause of the accuracy gap. The real cause was a
biased evaluation sample (an alphabetically-last-N slice, not random).
Fixing the sample surfaced the actual issue — two classes stuck near
chance level — which was then addressed by rebalancing training data.

**6. Which classes perform worst, and why?**
Spider Mite (40.0%) and Target Spot (43.3%), both well below the other
six (63-90%). Confusion-matrix analysis shows both overlap visually
with Septoria Leaf Spot specifically, not with each other — reads as a
feature-resolution limit for a model this small, not something more
training data alone would obviously fix (already tried doubling their
data, which helped from near-chance but didn't close the gap; two
further attempts — an imbalanced oversample and class-weighted loss —
both made results worse and are documented as rejected approaches).

**7. How do you know the on-device model and the cloud model behave
identically?**
They're not two models — it's the literal same `.tflite` file, used by
both the firmware (TFLite Micro) and the Lambda (`ai-edge-litert`).
Class-label order and INT8 quantization parameters are cross-checked
directly against `training_metadata.json` in tests, not assumed
consistent.

**8. How would you improve accuracy further?**
Real garden photos, not just PlantVillage's cropped plain-background
images — that's the single biggest known gap between measured and
real-world accuracy. Also worth trying: a slightly larger model now
that PSRAM headroom is confirmed available, and targeted data
collection specifically for the Spider Mite/Septoria/Target Spot
confusion triangle.

## Embedded questions

**9. How does the pump safety timer work, and what bug did you find in
it?**
It tracks *who* started the pump (`pumpStartedByAuto`), not just the
current mode. The bug: gating the safety cutoff on "current mode ==
AUTO" has a hole — if a user switches to manual mid-cycle, the cutoff
would silently stop applying and the pump could run indefinitely.
Fixed by tracking pump-start origin instead of re-checking current
mode.

**10. Describe a real bug you found in the camera pipeline.**
RGB565 byte order. The ESP32 camera driver emits pixels big-endian;
reading them through a native `uint16_t*` cast on a little-endian MCU
silently byte-swapped every pixel — colors would come out wrong with
no error or crash. Fixed by explicitly combining the two bytes in the
right order in `preprocessFrame()`.

**11. What was the PSRAM issue?**
The TFLite Micro tensor arena (~250 KB) as a plain static array
overflowed the ESP32's ~320 KB of internal DRAM by about 186 KB once
Wi-Fi and WebServer buffers were also counted — caught by the compiler/
linker in CI, not discovered by guessing. Fixed by allocating the arena
in PSRAM via `heap_caps_malloc` instead of as a static array.

**12. How did you test firmware without physical hardware?**
Split hardware-independent logic (pump state machine, thresholds,
RGB565 decode, INT8 quantize/dequantize) into plain C++ headers with no
Arduino/ESP32 dependencies, then unit-tested them with a plain `g++`
compiler in CI — real execution of real production logic, just without
the actual board. Separately, both full sketches are compiled (not
just the logic headers) against real ESP32 board definitions on every
push, which catches real compile-time errors a logic-only test can't.

**13. What doesn't host-testing prove?**
Anything requiring real hardware timing, real sensor electrical
behavior, real relay switching, or real Wi-Fi radio behavior. That's
explicitly still marked BLOCKED, not glossed over.

## Flutter questions

**14. How does the app talk to the ESP32 nodes?**
Plain HTTP/REST over the local Wi-Fi network — both nodes and the phone
need to be on the same network. `Esp32Service` wraps the calls with
proper error handling (a real bug was found here: a malformed JSON
response was letting a raw `FormatException` reach the UI instead of
the app's own typed exception).

**15. Why did History break on web, and how did you find it?**
`sqflite` has no browser implementation at all — no platform channels
in a browser context. Found via a real, isolated headless-Chromium
(Playwright) run that actually loaded the built web app: History threw
`databaseFactory not initialized` instead of loading. Fixed by adding
`sqflite_common_ffi_web` and setting `databaseFactory` conditionally
behind `kIsWeb`, with zero changes needed to the database access code
itself, since it already went through `sqflite`'s pluggable factory.

**16. How did you test the app without a real ESP32?**
Built a local Dart server (`esp32_simulator_lib.dart`) that serves the
exact same JSON shapes and status codes as the real firmware's REST
API, then ran the real, unmodified `Esp32Service` against it over real
loopback HTTP in an integration test — the app code under test is
identical to what would run against a real device.

## AWS questions

**17. Walk me through the AWS request flow.**
`POST /diagnose` → `upload_handler` Lambda decodes/validates the image,
writes it to S3, enqueues a job in SQS, returns a `diagnosisId`
immediately. SQS triggers `inference_handler` asynchronously, which
reads the image from S3, runs real INT8 inference, writes the result
to DynamoDB. The app polls `GET /diagnose/{id}` via `results_handler`
until status flips to `complete`.

**18. Why async instead of synchronous inference in the same request?**
Decouples the API's response time from inference latency and lets
inference scale independently — the same pattern real production
image-processing pipelines use. It also means a slow/failed inference
doesn't tie up an API Gateway connection.

**19. How are IAM permissions scoped?**
Each Lambda has its own SAM-managed policy scoped to the specific
resource it needs by name — `S3CrudPolicy`/`S3ReadPolicy` bound to the
one bucket, `SQSSendMessagePolicy`/`SQSPollerPolicy` bound to the one
queue, `DynamoDBCrudPolicy`/`DynamoDBReadPolicy` bound to the specific
table each function owns. No wildcard `Resource: "*"` anywhere —
verified directly by reading the template, not assumed.

**20. Describe a real deployment bug you found.**
The Lambda Layer's shared code (`common_layer`) failed to import in
production with `No module named 'common'`, despite passing every
local test. Root cause, confirmed by downloading and inspecting the
actual deployed layer zip: the layer's source already had the
Lambda-required `python/` subfolder, but SAM's build metadata
(`BuildMethod: python3.12`) made the builder add *another* `python/`
prefix during build, double-nesting the path. Invisible to any local
test because they add the layer source directly to `sys.path`,
bypassing SAM's build step entirely. Fixed by removing the redundant
subfolder so the builder's own prefixing produces the correct path.

**21. How do you know the deployment actually works, not just that
`sam deploy` succeeded?**
Ran a real smoke test against the live API after deploying: a real
image through `POST /diagnose`, polled until `complete`, confirmed a
real class and confidence came back from the actual model — then
independently verified the result directly in DynamoDB (`get-item`)
and the image directly in S3 (`s3 ls`), not just trusting the API
response.

**22. Why `workflow_dispatch` only for the deploy workflow?**
Deliberate safety choice — it creates real, billable AWS resources, so
it should never fire automatically on a push. Same reasoning applies
to the Wokwi simulation workflow, even though that one has no cost
implication, for consistency.

## Security questions

**23. How are credentials handled?**
AWS keys and the Wokwi CI token are stored only as GitHub encrypted
repository secrets, referenced in workflows as `${{ secrets.X }}`, never
as literal values, never printed, never committed. GitHub automatically
masks any secret value that appears in a log. `.env` files (Gemini API
key, ESP32 host IPs) are gitignored and were never committed — checked
directly against the full git history, not just the current tree.

**24. What's the actual attack surface of the AWS API?**
It's a public, unauthenticated API by design (no login system in this
project), with open CORS (`AllowOrigin: '*'`) — a deliberate, pre-
existing choice appropriate for a project with no user accounts, not
something introduced carelessly. IAM scoping (see Q19) limits what a
compromised function could do; there's no admin/write access to
anything beyond each function's own resource.

**25. Did you find any real credential leaks during this project?**
No — checked directly, not assumed: full git history scanned for
`.env` files ever committed and for AWS/API key-shaped string patterns,
both clean. One real hardening fix was made though: an early version of
the deploy workflow interpolated a secret directly into shell script
text (`${{ secrets.X }}` inline in a `run:` block) instead of passing
it via `env:` — a documented GitHub Actions anti-pattern, low risk here
since that particular secret wasn't sensitive, but fixed properly
anyway.

## Testing questions

**26. What's your test coverage story?**
Not a coverage-percentage story — a "what's actually verified vs.
what's explicitly not" story. 19 backend tests (real handler code,
mocked AWS), 19 Flutter tests (including real integration tests
against a protocol-accurate simulator), firmware host tests for all
hardware-independent logic, a real AWS deployment smoke test, and a
real Wokwi simulation. Every doc in this repo distinguishes CI
validation / local testing / simulated testing / real deployment
validation / physical hardware validation as different things, and
nothing claims a stronger category than what was actually done.

**27. What's not tested, and why?**
Physical ESP32/ESP32-CAM hardware and a physical/emulated mobile
device — both genuinely unavailable in this development environment.
Stated as BLOCKED everywhere, never implied to be covered by
simulation or host tests.

**28. How did you catch the `moto`/AWS-credentials test-ordering bug?**
A real, observed CI failure: after adding real AWS credentials to the
deploy workflow, previously-passing `moto`-mocked tests started hitting
real `ResourceNotFoundException`/`QueueDoesNotExist` errors instead of
the mock. Root cause: `moto`'s request interception becomes unreliable
once real credentials also exist in the process environment. Fixed by
reordering the workflow to run tests *before* configuring real AWS
credentials, rather than trying to make the mock coexist with real
creds.

## Deployment questions

**29. What would you need to actually go to production with this?**
Real hardware bring-up and validation (the biggest gap), real-world
model fine-tuning on actual garden photos, authentication on the AWS
API if it were to accept traffic from untrusted users, and a decision
on whether the AWS path or Gemini-direct is the long-term default
(currently Gemini-direct, with AWS as a demonstrated alternative).

**30. If you had one more week, what would you work on?**
Getting real ESP32 hardware to close the two BLOCKED items — that's
the highest-value remaining gap, since everything else already has
real evidence behind it. Second priority: real-world model accuracy
data from actual garden photos rather than only PlantVillage's
cropped, plain-background images.
