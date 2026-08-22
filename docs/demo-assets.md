# Demo assets

What already existed in the repository, and what was added
specifically for demo purposes. Everything here is safe to run
publicly: no secrets, no real personal data, fully reproducible.

## What already existed (reused, not duplicated)

- **`mobile_app/tool/esp32_simulator.dart`** / **`esp32_simulator_lib.dart`**
  — a real local server matching the exact REST contract of both
  physical ESP32 nodes. Useful for demoing the Flutter app's
  Sensors/Irrigation screens *with* live-looking data instead of
  "could not reach" errors, if you want that for a specific audience.
  Run with `dart run tool/esp32_simulator.dart` from `mobile_app/`,
  then point `.env`'s `IRRIGATION_NODE_HOST`/`VISION_NODE_HOST` at
  `127.0.0.1:<port>` (see [`docs/simulation.md`](simulation.md) for the
  exact port and contract).
- **`backend/tests/test_lambda_handlers_local.py`** already generates
  synthetic test images inline (`PIL.Image.new(...)`) for its own
  tests — the pattern `demo/generate_demo_payload.py` (below) follows,
  factored out into a standalone, reusable script since the test
  file's version isn't meant to be imported or run standalone.

## What was added — `demo/generate_demo_payload.py`

**Clearly labeled DEMO** (in its own top-level `demo/` directory, with
a `DEMO SCRIPT` header comment) — not part of the application, not
part of the test suite, not imported by anything else in the
repository.

**What it does**: generates a small, deterministic 96×96 solid-color
JPEG (always the same green, `(34, 139, 34)`) and writes a ready-to-
`curl` `demo/payload.json` containing its base64 encoding.

**Why solid-color, not a real leaf photo**: no real leaf photo ships
in this repository (the PlantVillage dataset directory is gitignored
and not redistributed here — see [`docs/dataset.md`](dataset.md) for
licensing), and using one would risk implying the demo's specific
prediction is meaningful when the actual point is demonstrating that
the pipeline runs real inference end-to-end. The script's own output
says this plainly.

**Reproducibility**: same color, same size, every run — the generated
`payload.json` is byte-for-byte identical across runs (modulo JPEG
encoder determinism, which Pillow provides). Not committed to the
repository (gitignored) since it's fully regeneratable output, not
source.

**Verified working**: actually run against the real, live deployed API
as part of this audit —
```
$ python demo/generate_demo_payload.py
Wrote demo/payload.json (1032 base64 chars)
$ curl -X POST "https://p17huf2s49.execute-api.ap-south-1.amazonaws.com/prod/diagnose" \
    -H "Content-Type: application/json" -d @demo/payload.json
{"diagnosisId": "2bd72147-f383-4066-aff3-314458eb2510"}
```
Real `202`-equivalent response, real `diagnosisId`, confirmed against
the live stack, not assumed to work.

## How to use it

```bash
pip install Pillow
python demo/generate_demo_payload.py
curl -X POST "https://p17huf2s49.execute-api.ap-south-1.amazonaws.com/prod/diagnose" \
  -H "Content-Type: application/json" -d @demo/payload.json
# -> {"diagnosisId": "..."}
curl "https://p17huf2s49.execute-api.ap-south-1.amazonaws.com/prod/diagnose/<id-from-above>"
# -> {"status": "complete", "diseaseName": "...", "confidence": ...} once inference finishes
```

If you want a real classification result to demonstrate the model's
actual accuracy (rather than just the pipeline mechanics), substitute
a real tomato leaf photo you have separate rights to use — encode it
the same way (`base64.b64encode(open('leaf.jpg','rb').read())`) and
build the same `{"imageBase64": ..., "mimeType": "image/jpeg"}`
payload shape by hand instead of using this script.

## What NOT to use for a demo

- Any real PlantVillage image with attribution/redistribution
  restrictions beyond what [`docs/dataset.md`](dataset.md) documents
  — don't imply this repository redistributes the dataset, since it
  doesn't
- Real device IP addresses from someone else's network — the
  irrigation/vision node hosts in `.env.example` are placeholders
  (`192.168.1.50`/`.51`) for a reason
