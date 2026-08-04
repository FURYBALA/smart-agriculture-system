# Differences from the original project report

This repo rebuilds the team's Nov 2025 project report into working
code. Some pieces were rebuilt faithfully; some had to be substituted
or newly written because the original tooling/access wasn't available
in the environment this was built in. Listed honestly below so nobody
is surprised in a demo or an interview.

## TinyML disease model: rebuilt with TensorFlow, not Edge Impulse

The report's model was trained on **Edge Impulse** (94.1% F1, 120
images total: 96 train / 24 test, 822ms inference) — that Edge
Impulse project/export wasn't available when this repo was built.

What's here instead: a CNN trained from scratch with TensorFlow/Keras
on the same 8 disease classes, using a larger slice of the public
PlantVillage dataset (200 images/class instead of ~15). **Actual
measured result: 69.7% float validation accuracy** — well below the
report's 94.1% F1, which came from a 120-image dataset (~15
images/class) that's a strong candidate for overfitting to look
better than it generalizes. After INT8 quantization for the
microcontroller, accuracy drops further to 51.7% on a spot-check —
a real, documented gap, not swept under the rug. See
[`docs/dataset.md`](dataset.md#results) for the full numbers and what
to try next.

**One class had to be substituted entirely**: the report's "Bacterial
Speck (*Pseudomonas syringae*)" has no equivalent in PlantVillage,
which only has "Bacterial Spot" (*Xanthomonas* spp. — a different,
related disease). `Bacterial_Spot` is used as the closest available
proxy. If you have real Bacterial Speck images, swap the class and
retrain — see [`ml/scripts/`](../ml/scripts/).

If you have the original Edge Impulse export, it can replace
`firmware/vision_node/model_data.h` and `class_labels.h` directly —
see [`docs/bring-up-checklist.md`](bring-up-checklist.md).

## Irrigation node: REST API newly built to match the report's claim

The report states the ESP32 irrigation node "is fully integrated with
the app through REST APIs." The original firmware (in this team's
working files) only had Serial output and an optional SinricPro/Alexa
integration — no HTTP server existed. `firmware/irrigation_node` is a
real implementation of that REST API claim: `/sensors`, `/mode`,
`/pump/on`, `/pump/off`, matching what the Flutter app's Sensor
Dashboard and Irrigation Control screens actually call.

## Vision node: app integration added, differently than planned

The report explains the ESP32-CAM couldn't be integrated with the
mobile app because **live MJPEG video streaming** was unreliable on
that hardware, so results were read from the Serial Monitor only.

`firmware/vision_node` doesn't attempt MJPEG streaming at all — it
runs inference locally and exposes only the *latest classification
result* as a small JSON payload (`GET /latest`), which the Diagnosis
screen can poll. This sidesteps the specific streaming problem rather
than solving it, and is a much lighter integration than video.

## Mobile app: built from scratch

No Flutter code existed anywhere accessible when this repo was built
— the report describes the app's screens and behavior, but not its
implementation. `mobile_app/` is new code implementing the six
described modules (Sensor Dashboard, Irrigation Control, AI Disease
Diagnosis via Gemini Vision, History, Chatbot, Device Connectivity
Tests). It's verified with `flutter analyze` (clean) and `flutter
test` (passing) — real automated checks, not just "should work."

## Cloud backend: written to match the diagram, not deployed

The report's Figure 3.3 shows an AWS architecture (API Gateway, S3,
SQS, Lambda inference, DynamoDB) with no implementation detail in the
text. `backend/` is a real, deployable AWS SAM implementation of that
diagram — but nobody has run `sam deploy` on it. The mobile app's
actual diagnosis flow calls Gemini Vision directly and doesn't need
this backend at all; it exists as the self-hosted alternative the
diagram describes. See [`backend/README.md`](../backend/README.md).

## What's still unverified

- **Neither firmware sketch has been compiled or flashed to real
  hardware** — this environment had no ESP32 toolchain or physical
  board. Both were written carefully against the correct APIs and
  reviewed, but see
  [`docs/bring-up-checklist.md`](bring-up-checklist.md) before your
  first flash.
- **The Flutter app hasn't run on a device or emulator** — no
  Android/iOS emulator was available here. Static analysis and the
  widget test suite pass, which is a real (if partial) signal, but
  it's not the same as seeing it run.
