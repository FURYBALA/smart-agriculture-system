# Recruiter-facing version

Strong, specific wording — every claim below is backed by real,
checkable evidence elsewhere in this repository (see
[`docs/final-release-status.md`](final-release-status.md)). Nothing
here says "production-scale," "99% accurate," "hardware tested,"
"mobile device tested," or claims real-world deployment — none of
those are true, and this doc avoids implying them.

## 1-line description

Smart Agriculture System — ESP32 irrigation + on-device ML disease
detection, a Flutter app, and a deployed AWS serverless backend, built
and tested end-to-end without physical hardware.

## 3-line description

Built a dual-node ESP32 IoT system for automated irrigation and
on-device plant disease detection, unified in a Flutter app with an
optional AWS serverless inference pipeline. Trained and quantized a
custom CNN to run on-device, deployed the AWS backend for real, and
verified the full stack with 38+ automated tests plus a real circuit
simulation in CI. No physical hardware was available, so every claim
here is scoped precisely to what was actually tested.

## 30-second explanation

"I built a smart agriculture system combining IoT and AI. Two ESP32
microcontrollers handle automated soil irrigation and on-device plant
disease detection using a custom machine learning model I trained and
quantized myself. A Flutter app unifies both, and I separately
deployed a full AWS serverless backend as an alternative cloud
inference path — real infrastructure, actually deployed and verified
end-to-end. I didn't have physical hardware during development, so I
built real automated test infrastructure instead, including getting a
circuit simulator to actually boot the real firmware in CI."

## 60-second explanation

"It's a two-part embedded system. One ESP32 automates irrigation —
reads soil moisture and temperature/humidity, drives a relay pump with
a safety cutoff timer. The other, an ESP32-CAM, runs a custom
convolutional neural network I trained from scratch and quantized to
INT8, classifying 8 tomato leaf conditions directly on-device via
TensorFlow Lite Micro.

Both connect to a Flutter app I built — six screens, live sensor data,
irrigation control, disease diagnosis, history, and an AI chatbot. For
diagnosis, the app also has a cloud path: I deployed a complete
serverless AWS backend — API Gateway, Lambda, S3, SQS, DynamoDB — as
an alternative to calling a third-party vision API, and I've run real
images through it end-to-end, verified directly against the deployed
resources, not just trusting the API's own response.

Without physical hardware available, I built real test coverage
instead — 38-plus automated unit and integration tests across
firmware, backend, and mobile, and I got a circuit simulator (Wokwi)
to actually boot the real production firmware, which took real
debugging since it initially failed for reasons that turned out not to
be obvious."

## Resume bullets

**1 bullet:**
Built and deployed a dual-node ESP32 IoT system with on-device ML
disease detection (custom CNN, INT8 TFLite), a Flutter app, and a real
AWS serverless backend (API Gateway/Lambda/S3/SQS/DynamoDB), verified
end-to-end with 38+ automated tests and a CI-integrated circuit
simulation.

**3 bullets:**
- Designed and implemented a dual-node ESP32 IoT system — automated
  soil-moisture irrigation and on-device tomato disease classification
  via a custom CNN trained from scratch and quantized to INT8 (69.9 KB)
- Built a 6-screen Flutter app and deployed a serverless AWS backend
  (API Gateway → Lambda → S3 → SQS → DynamoDB) as infrastructure-as-
  code, verified live with real end-to-end API tests
- Delivered 38+ automated tests (C++, Python, Dart) and a real
  firmware circuit simulation reproducible in CI, root-causing and
  fixing genuine bugs at every layer — from a biased ML evaluation
  sample to a production-only Lambda packaging defect

**5 bullets:**
- Designed and implemented a dual-node ESP32 IoT system: closed-loop
  automated irrigation with an origin-tracked pump safety timer, and
  an ESP32-CAM running on-device 8-class disease classification via
  TensorFlow Lite Micro
- Trained a custom CNN from scratch (81.9% float validation accuracy)
  and quantized it to INT8 (69.9 KB); root-caused an apparent
  quantization accuracy regression to a biased evaluation sample via
  image-by-image prediction comparison, then measurably improved the
  weakest classes through targeted data rebalancing
- Built a 6-screen Flutter app (Provider state management) with
  platform-conditional persistence, verified with a real headless-
  browser end-to-end test that found and fixed a web-only crash
- Architected and deployed a serverless AWS backend as infrastructure-
  as-code (AWS SAM) with least-privilege IAM, verified live via a real
  async upload → inference → poll flow, and found/fixed a production-
  only Lambda Layer packaging bug invisible to any local test
- Delivered 38+ automated tests across three languages plus a real
  circuit simulation (Wokwi) integrated into CI on a clean Ubuntu
  runner, after root-causing a zero-output stall by diffing against a
  known-working reference project

## Role-specific versions

### Software Engineer

"I built a full-stack embedded + mobile + cloud system: ESP32 firmware
in C++, a Flutter mobile app in Dart, and a serverless AWS backend in
Python — three different runtimes, one coherent system. I wrote 38+
automated tests across all three, set up 4 CI workflows, and found and
fixed real bugs at every layer: a state-tracking bug in the pump
safety logic, a byte-order bug in camera frame decoding, a DynamoDB
type-serialization bug, and a CI-only test-ordering conflict between a
mocking library and real credentials."

### Full Stack Engineer

"End-to-end ownership: embedded firmware (C++/ESP32) → REST APIs →
Flutter mobile app (Dart) → serverless AWS backend (Python/Lambda) →
DynamoDB. I designed the async upload-queue-process-poll pattern for
the cloud inference pipeline, built the mobile app's state management
and platform-conditional persistence layer, and deployed and verified
the whole backend against a real AWS account via CI/CD."

### ML/AI Engineer

"Trained a custom CNN from scratch for 8-class tomato disease
classification, then quantized it to INT8 (69.9 KB) for on-device
TensorFlow Lite Micro inference on an ESP32-CAM. When quantized
accuracy looked significantly worse than float, I didn't assume
quantization was the cause — I compared float and quantized
predictions image-by-image, found 99.2% agreement, and traced the real
issue to a biased evaluation sample. Fixing that surfaced genuinely
weak classes, which I improved via targeted training-data rebalancing,
documenting two further approaches that didn't work rather than
hiding them."

### Embedded/IoT Engineer

"Built two ESP32 nodes from scratch in C++: an irrigation controller
with sensor fusion (DHT11 + analog soil ADC) driving a relay pump
through an origin-tracked safety-timer state machine, and an
ESP32-CAM running on-device TensorFlow Lite Micro inference with a
PSRAM-allocated tensor arena (found and fixed a real 186 KB internal-
DRAM overflow). Found and fixed a real RGB565 byte-order bug in camera
frame decoding. Extracted all hardware-independent logic into
host-testable headers, verified in CI with a plain `g++` compiler —
and got a circuit simulator (Wokwi) to actually boot the real firmware
in an automated CI pipeline, after root-causing a genuine
configuration defect."

### Cloud/AWS Engineer

"Designed and deployed a serverless AWS backend — API Gateway, Lambda,
S3, SQS, DynamoDB — as infrastructure-as-code (AWS SAM), with an
async upload → queue → process → poll architecture and least-
privilege IAM (every function's policy scoped to the one resource it
needs by name, no wildcards). Deployed via a manual-gated GitHub
Actions pipeline with credentials only ever handled as encrypted
secrets. Found and fixed a real production-only Lambda Layer packaging
bug by downloading and inspecting the actual deployed artifact — the
kind of defect no local test can catch since local tests bypass SAM's
build step entirely."
