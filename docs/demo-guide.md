# Demo guide — no physical hardware required

This is a real, run-it-yourself demo procedure. Every command below has
actually been executed against the real, currently-deployed system as
part of this repository's own verification work — nothing here is
aspirational. It deliberately avoids anything that needs a physical
ESP32, ESP32-CAM, or mobile device, since none of those are available
in this project's development environment (see
[`docs/final-validation-matrix.md`](final-validation-matrix.md) for
exactly what that does and doesn't limit).

**What's real vs. simulated in this demo**, stated up front so nothing
is ambiguous while presenting:

| Piece | Status |
|---|---|
| AWS backend (API Gateway, Lambda, S3, SQS, DynamoDB) | **Real** — a live, deployed AWS account |
| ML inference (INT8 TFLite model) | **Real** — the actual trained model, actually run |
| Flutter web app | **Real** — actually built and run in a browser |
| Irrigation firmware boot/logic | **Simulated** — Wokwi, not a physical ESP32 |
| Soil moisture / temperature / humidity readings | **Simulated** — a virtual potentiometer and DHT sensor in Wokwi, not real sensors |
| Pump/relay | **Simulated** — an LED standing in for the relay in Wokwi |
| ESP32-CAM camera capture | **Not demoed** — Wokwi cannot simulate a camera at all (see below); not claimed |

---

## Prerequisites (one-time setup)

```bash
git clone https://github.com/FURYBALA/smart-agriculture-system
cd smart-agriculture-system
```

For the Wokwi part: a free account at [wokwi.com](https://wokwi.com)
and a CI token from your [Wokwi dashboard](https://wokwi.com/dashboard/ci)
(only needed for the CLI route below — the browser-IDE route needs no
token at all, see Part 1).

For the Flutter web part: [Flutter SDK](https://flutter.dev) installed
(`flutter --version` should print something).

Nothing else needs installing — the AWS backend is already deployed;
you're calling a real, live API, not standing one up yourself.

---

## 5-minute demo

For a short walkthrough — pitch meeting, quick project check-in.

### 1. Show the live AWS backend responding (60 seconds)

```bash
curl -X POST "https://p17huf2s49.execute-api.ap-south-1.amazonaws.com/prod/diagnose" \
  -H "Content-Type: application/json" \
  -d '{"imageBase64":"<base64-jpeg>","mimeType":"image/jpeg"}'
```

Expected output (immediately):
```json
{"diagnosisId": "2a7a52f9-e4e8-43aa-9011-acf817390780"}
```

Then poll it:
```bash
curl "https://p17huf2s49.execute-api.ap-south-1.amazonaws.com/prod/diagnose/2a7a52f9-e4e8-43aa-9011-acf817390780"
```

Expected output (a few seconds later, once the async pipeline finishes):
```json
{"diagnosisId": "2a7a52f9-e4e8-43aa-9011-acf817390780", "status": "complete", "diseaseName": "TYLCV", "confidence": 0.996}
```

**What to explain while this runs**: the first call returns instantly
(`202`-style accepted response) because the image upload, S3 write, and
SQS enqueue happen synchronously in `upload_handler`, but the actual
model inference runs *asynchronously* in a separate Lambda
(`inference_handler`) triggered by the queue — so the second `curl` is
polling for a result that a completely different, independently-scaled
function produced. This is the same async pattern real production
image-processing pipelines use, not a toy shortcut.

*(No real leaf photo handy? Any JPEG works for this call — the point
being demonstrated is the pipeline, not that specific prediction. See
"Generating a test image" below if you want a throwaway one.)*

### 2. Show the Flutter app running in a browser (2 minutes)

```bash
cd mobile_app
flutter build web
cd build/web && python -m http.server 8123
```
Open `http://127.0.0.1:8123/` in a browser. Click through the 6 tabs
(Sensors, Irrigation, Diagnose, History, Chat, Device) at the bottom.

**What to explain**: this is the real compiled app, not a mockup — the
same code that would run on a phone. Sensors/Irrigation will show
"could not reach" errors since there's no real ESP32 on this network,
which is the app's actual, tested error-handling path working
correctly, not a bug.

### 3. Show the Wokwi simulation passing in CI (90 seconds)

Open the most recent successful run:
https://github.com/FURYBALA/smart-agriculture-system/actions/workflows/wokwi-simulation.yml

Click into the `simulate` job → `Run Wokwi simulation` step. Point out
the real ESP32 boot log and the `WOKWI_IRRIGATION_READY` /
`TEST PASSED.` lines.

**What to explain**: this is the actual production firmware, compiled
fresh and booted in a real (if virtual) ESP32 CPU simulation — not a
mock or a stub. It's automated, so it fails loudly if a future change
breaks boot.

---

## 10-minute detailed demo

Everything above, plus:

### 4. Run the Wokwi simulation live and watch it (3–4 minutes)

This is the visual, interactive version — worth doing live if you want
the audience to actually watch a "circuit" run, not just read a log.

1. Go to [wokwi.com](https://wokwi.com) → **+ New Project** → **ESP32**
2. Replace the default `diagram.json` with
   [`firmware/irrigation_node/wokwi/diagram.json`](../firmware/irrigation_node/wokwi/diagram.json)
3. Add two file tabs named `config.h` and `irrigation_logic.h`, and
   paste in the contents of
   [`firmware/irrigation_node/config.h`](../firmware/irrigation_node/config.h)
   and
   [`firmware/irrigation_node/irrigation_logic.h`](../firmware/irrigation_node/irrigation_logic.h)
4. Replace the main sketch tab with
   [`firmware/irrigation_node/irrigation_node.ino`](../firmware/irrigation_node/irrigation_node.ino)
5. Click **▶ Run**

Expected: the ESP32, DHT sensor, potentiometer, and LED render
visually; the serial monitor panel prints the real boot log ending in
`WOKWI_IRRIGATION_READY`, then `Connecting to Wi-Fi.....` (this never
resolves — `config.h`'s Wi-Fi credentials are an intentional
real-deployment placeholder, not a real network Wokwi can join; explain
this rather than let it look like a hang).

Turn the potentiometer (click-drag) to show the soil-moisture reading
would change if this were wired to real logic observing it (the REST
server itself never starts here, since it's gated behind the Wi-Fi
connection that never completes in simulation — say this plainly
rather than imply otherwise).

### 5. Show the AWS resources directly (2 minutes)

If you have AWS CLI access to the account:
```bash
aws cloudformation describe-stacks --stack-name smart-agriculture-system --region ap-south-1 \
  --query "Stacks[0].{Status:StackStatus,Outputs:Outputs}"
```
Expected: `"Status": "UPDATE_COMPLETE"`, and the same live API URL used
in step 1. Or just walk through the AWS Console: Lambda (4 functions),
DynamoDB (2 tables), S3 (1 bucket with a 90-day expiry lifecycle rule),
SQS (1 queue).

**What to explain**: this is a real AWS account with real billable
resources, not LocalStack or a mock — the same infrastructure pattern
production systems use, deployed via infrastructure-as-code (AWS SAM),
not clicked together by hand.

### 6. Show the chat API (1 minute)

```bash
curl -X POST "https://p17huf2s49.execute-api.ap-south-1.amazonaws.com/prod/chat/demo-session" \
  -H "Content-Type: application/json" \
  -d '{"role":"user","text":"What does TYLCV mean for my tomato plants?"}'
```
Expected: `{"status": "saved"}`. Then:
```bash
curl "https://p17huf2s49.execute-api.ap-south-1.amazonaws.com/prod/chat/demo-session"
```
Expected: the message you just sent, round-tripped through DynamoDB.

### 7. Show real test suites passing (2 minutes)

```bash
cd backend && python -m pytest tests/ -v
cd ../mobile_app && flutter test
```
Expected: `19 passed` for both. Point out specific tests worth
mentioning: `test_run_one_end_to_end_writes_a_valid_class_prediction`
(real model inference, not mocked) and
`test_esp32_service_handles_malformed_json` (a real bug this project
found and fixed).

---

## Generating a throwaway test image

If you don't have a real leaf photo handy for the `curl` demo:
```bash
python3 -c "
import base64, io, json
from PIL import Image
img = Image.new('RGB', (96, 96), color=(34, 139, 34))
buf = io.BytesIO()
img.save(buf, format='JPEG')
print(json.dumps({'imageBase64': base64.b64encode(buf.getvalue()).decode(), 'mimeType': 'image/jpeg'}))
" > payload.json
curl -X POST "https://p17huf2s49.execute-api.ap-south-1.amazonaws.com/prod/diagnose" \
  -H "Content-Type: application/json" -d @payload.json
```
Say plainly that this is a solid-color placeholder image, not a real
leaf — the point is demonstrating the pipeline runs real inference
end-to-end, not that the resulting classification is meaningful for a
plain green square.

## Screenshots worth capturing ahead of time

(In case live network/AWS access isn't available during the actual
presentation — see fallback below.)

1. The `curl` request/response pair from step 1
2. The Flutter web app's Sensors tab and Diagnose tab (empty states are
   fine and honest — that's the real, current state)
3. The Wokwi GitHub Actions run log, `Run Wokwi simulation` step
   expanded, showing `WOKWI_IRRIGATION_READY` / `TEST PASSED.`
4. The Wokwi web IDE mid-run, showing the rendered circuit
5. `flutter test` and `pytest` terminal output showing `19 passed`
   each
6. AWS Console: CloudFormation stack overview showing `UPDATE_COMPLETE`
   and the 21 resources

## Fallback procedure if AWS or Wokwi is temporarily unavailable

Both are real third-party/cloud services and can have outages
independent of this project. If either is down during a live demo:

- **AWS unreachable**: fall back to `backend/tests/test_lambda_handlers_local.py`
  — run `cd backend && python -m pytest tests/ -v -k RealInference`
  live instead. This exercises the *real* model and *real* handler code
  against `moto`-mocked AWS, so it's still real inference, just not
  against the live deployed API. Say this distinction out loud rather
  than implying it's the same as step 1.
- **Wokwi unreachable**: fall back to the firmware host tests instead —
  `firmware/test/test_irrigation_logic.cpp` compiled and run with
  `g++` (see [`docs/host-testing.md`](host-testing.md)) exercises the
  same pump/threshold decision logic without needing Wokwi's cloud
  service at all. It won't show a "circuit," but it's real execution of
  real production logic, and CI screenshots (pre-captured, see above)
  cover the visual gap.
- **No internet at all**: use the pre-captured screenshots above and
  the CI badge history in the README, which already shows every
  workflow's pass/fail record without needing a live connection.
