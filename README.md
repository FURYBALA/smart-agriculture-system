# Smart Agriculture System with Plant Disease Detection

A dual-node IoT + AI system: automated soil-moisture irrigation, and
on-device + cloud plant disease diagnosis, unified in one mobile app.

[![Firmware compile check](https://github.com/FURYBALA/smart-agriculture-system/actions/workflows/firmware-compile.yml/badge.svg)](https://github.com/FURYBALA/smart-agriculture-system/actions/workflows/firmware-compile.yml)
[![Flutter CI](https://github.com/FURYBALA/smart-agriculture-system/actions/workflows/flutter-ci.yml/badge.svg)](https://github.com/FURYBALA/smart-agriculture-system/actions/workflows/flutter-ci.yml)

Built for **21ECC301P — Microprocessor, Microcontroller and Interfacing
Techniques**, SRM Institute of Science and Technology. See
[`docs/team.md`](docs/team.md) for the team and guide.

> This repo rebuilds the team's original project report into working,
> version-controlled code. Not every piece could be reproduced exactly
> as reported (no access to the original Edge Impulse project, no AWS
> account to deploy to) — every substitution is documented plainly in
> [`docs/differences-from-report.md`](docs/differences-from-report.md).
> Nothing here claims results it didn't actually produce.

## Architecture

```
┌─────────────────────┐        ┌──────────────────────┐
│  Irrigation Node     │        │   Vision Node         │
│  ESP32                │        │   ESP32-CAM            │
│                       │        │                        │
│  DHT11 + soil sensor  │        │  On-device TFLite      │
│  → relay → pump       │        │  8-class disease model │
│  REST API             │        │  REST API (/latest)    │
└──────────┬────────────┘        └───────────┬────────────┘
           │  same Wi-Fi                      │  same Wi-Fi
           └───────────────┬──────────────────┘
                            │
                  ┌─────────▼─────────┐
                  │   Flutter App       │
                  │                     │
                  │  Sensor Dashboard   │
                  │  Irrigation Control │
                  │  Disease Diagnosis ─┼──→ Gemini Vision API
                  │  History            │
                  │  Chatbot ───────────┼──→ Gemini (text)
                  │  Device Tests       │
                  └─────────┬───────────┘
                            │  optional
                  ┌─────────▼───────────┐
                  │  Cloud Backend        │
                  │  (not deployed)       │
                  │  API GW → S3 → SQS →  │
                  │  Lambda → DynamoDB    │
                  └───────────────────────┘
```

## Repository layout

```
firmware/
  irrigation_node/   — ESP32: sensing + pump control + REST API
  vision_node/        — ESP32-CAM: on-device disease classification
ml/
  scripts/             — download, train, quantize the vision model
  models/              — trained model + metrics (generated)
mobile_app/            — Flutter app, all 6 modules
backend/                — AWS SAM cloud backend (not deployed)
docs/                   — team, architecture, wiring, dataset, bring-up
```

## Getting started

Each component has its own setup:

- **Firmware**: [`docs/wiring.md`](docs/wiring.md) then
  [`docs/bring-up-checklist.md`](docs/bring-up-checklist.md)
- **ML pipeline**: [`docs/dataset.md`](docs/dataset.md) — `pip install
  -r ml/requirements.txt`, then `download_dataset.py` → `train.py` →
  `convert_tflite.py`
- **Mobile app**: `cd mobile_app && flutter pub get`, copy `.env.example`
  to `.env` and fill in your Gemini API key and node IPs, then
  `flutter run`
- **Backend** (optional): [`backend/README.md`](backend/README.md)

## Results

| | |
|---|---|
| Disease classes | 8 tomato leaf conditions (see [`docs/dataset.md`](docs/dataset.md)) |
| Training data | 1,600 images, PlantVillage subset |
| Model | Custom CNN, 96×96×3 input, 61K params |
| Validation accuracy (float) | 69.7% |
| Quantized (INT8) model | 69.9 KB, 53.3% spot-check accuracy — quantization itself is ~lossless (99.2% prediction agreement with float); the real story is 2 of 8 classes the model hasn't learned well. Per-class breakdown in [`docs/dataset.md`](docs/dataset.md) |
| Mobile app | 6 modules, verified via `flutter analyze` + `flutter test` (passing) |
| CI | Both firmware sketches compile-checked on every push against real ESP32 board definitions; caught and fixed 2 real bugs |

The accuracy investigation is a good example of the standard this repo
holds itself to: the first hypothesis (thin INT8 calibration data) was
tested and ruled out, the real cause (a biased evaluation sample, not
quantization) was found by actually comparing predictions image-by-
image, and the underlying model weakness that was left after fixing
the bug (two classes near chance level) is reported plainly rather
than smoothed into a single "good enough" number. Full writeup:
[`docs/dataset.md`](docs/dataset.md#results).

## License

MIT — see [LICENSE](LICENSE). Training dataset separately attributed,
see [`docs/dataset.md`](docs/dataset.md).
