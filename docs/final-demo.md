# Final demo script (5-10 minutes)

A spoken-word demo script, section by section. For copy-paste commands
and screenshots to pre-capture, see [`docs/demo-guide.md`](demo-guide.md)
— this doc is the *narration*, that one is the *reference*. No secrets
appear anywhere in this script or its commands.

Total time: ~8-10 minutes read through completely; ~5 minutes if you
skip to A, C, D, G and summarize the rest.

---

## A. Project introduction (30 seconds)

> "This is a smart agriculture system — two ESP32 microcontrollers
> handle irrigation and plant disease detection, a Flutter app ties
> them together, and I deployed a full serverless AWS backend as an
> alternative cloud inference path. I built and tested all of it
> without physical hardware, so I want to be upfront about exactly
> what's real versus simulated as I go."

## B. Architecture explanation (60 seconds)

> "Three independent layers. Two ESP32 nodes — an irrigation node
> reading soil moisture and driving a pump, and an ESP32-CAM running
> an on-device disease-classification model — each expose a small REST
> API over local Wi-Fi. A Flutter app talks to both, plus Gemini AI
> directly for diagnosis and chat. And separately, I deployed a full
> AWS pipeline — API Gateway, Lambda, S3, SQS, DynamoDB — as an
> alternative diagnosis path, matching the architecture in the
> original project report."

Point to [`docs/architecture.md`](architecture.md)'s diagram if
screen-sharing.

## C. Flutter web demonstration (90 seconds)

```bash
cd mobile_app
flutter build web
cd build/web && python -m http.server 8123
```
Open `http://127.0.0.1:8123/`.

> "This is the real compiled app — same code that runs on a phone.
> I'll click through the six tabs."

Click Sensors → Irrigation → Diagnose → History → Chat → Device.

> "Sensors and Irrigation show 'could not reach' errors because
> there's no physical ESP32 on this network right now — that's the
> app's actual tested error-handling working correctly, not a bug I'm
> hiding."

## D. Live AWS diagnosis demonstration (90 seconds)

```bash
curl -X POST "https://p17huf2s49.execute-api.ap-south-1.amazonaws.com/prod/diagnose" \
  -H "Content-Type: application/json" -d @payload.json
```
(See [`docs/demo-assets.md`](demo-assets.md) for `payload.json`.)

> "That's a real request against a real, live AWS account — not
> localhost, not a mock."

Expected: `{"diagnosisId": "..."}` immediately.

```bash
curl "https://p17huf2s49.execute-api.ap-south-1.amazonaws.com/prod/diagnose/<id>"
```

> "Polling for the result — the actual inference runs asynchronously
> in a separate Lambda triggered by an SQS message, so this is a
> genuinely async pipeline, not a synchronous call dressed up to look
> like one."

Expected: `{"status": "complete", "diseaseName": "...", "confidence": ...}`.

## E. AWS result verification (60 seconds)

> "I don't just trust the API's own response — I've independently
> checked the result at the storage layer."

```bash
aws dynamodb get-item --table-name DiagnosisResults \
  --key '{"diagnosisId":{"S":"<id>"}}' --region ap-south-1
aws s3 ls s3://smart-agri-leaf-images-<account-id>/uploads/ --region ap-south-1
```

> "Same result, read directly from DynamoDB, and the uploaded image is
> genuinely sitting in S3. This isn't the API telling me what I want
> to hear — it's the actual data."

## F. Chat demonstration (45 seconds)

```bash
curl -X POST "https://p17huf2s49.execute-api.ap-south-1.amazonaws.com/prod/chat/demo-session" \
  -H "Content-Type: application/json" -d '{"role":"user","text":"What does TYLCV mean?"}'
curl "https://p17huf2s49.execute-api.ap-south-1.amazonaws.com/prod/chat/demo-session"
```

> "Same pattern — real write, real read-back, through a completely
> separate Lambda and DynamoDB table from the diagnosis flow."

## G. Wokwi simulation demonstration (90 seconds)

Open https://github.com/FURYBALA/smart-agriculture-system/actions/workflows/wokwi-simulation.yml
→ latest successful run → `simulate` job → `Run Wokwi simulation` step.

> "This is the actual production irrigation firmware, compiled fresh
> and booted in a real circuit simulator, running on GitHub's own
> Ubuntu servers — not just my machine. You can see the real ESP32 boot
> ROM output, then this line —" [point to `WOKWI_IRRIGATION_READY`] —
> "— that's a marker I added specifically so this test has something
> deterministic to check for automatically. `Expected text found`,
> `TEST PASSED`, exit code 0."

If time allows, also open the interactive version at wokwi.com (see
[`docs/demo-guide.md`](demo-guide.md#4-run-the-wokwi-simulation-live-and-watch-it-34-minutes))
to show the circuit rendering visually.

> "One thing I'll say plainly: Wokwi can't simulate a camera at all,
> so this only covers the irrigation node, not the vision node's
> camera path. I don't claim otherwise anywhere in this project."

## H. CI demonstration (30 seconds)

Open the repo's Actions tab, or point at the README badges.

> "Four CI workflows run automatically — firmware compile, Flutter,
> backend tests, and this Wokwi simulation. All green on the current
> commit."

## I. ML explanation (60 seconds)

> "The model's a custom CNN I trained from scratch — not transfer
> learning, since it needs to fit in about 70 KB after INT8
> quantization to run on the ESP32-CAM's limited RAM. 81.9% float
> accuracy, 65.8% after quantization on a held-out spot-check.

> That quantization gap looked concerning at first — an 18-point drop
> — so I didn't just accept it. I compared float and quantized
> predictions image-by-image and found 99.2% agreement, which ruled
> out quantization as the cause. The real problem was a biased
> evaluation sample. Fixing that surfaced two genuinely weak classes,
> which I then improved by rebalancing training data — a real,
> measured fix, documented alongside two other approaches that
> actually made things worse."

## J. Security explanation (30 seconds)

> "AWS credentials and the Wokwi CI token live only as GitHub encrypted
> secrets, never printed, never committed — I checked the full git
> history to confirm that, not just the current state. The deploy
> workflow only ever runs manually, never automatically on a push.
> Every Lambda's IAM permissions are scoped to only the one resource it
> needs, no wildcards."

## K. Limitations (30 seconds)

> "To be direct about what isn't proven: no physical ESP32 or
> ESP32-CAM hardware was available, so real sensor accuracy, relay
> behavior, and camera quality are untested. No physical or emulated
> mobile device either — though the web version has been really
> tested, not just built. And Wokwi genuinely can't simulate a
> camera, so the vision node's actual capture path has no simulation
> coverage at all, only host-side logic tests."

## L. Future improvements (30 seconds)

> "Top priority is getting real hardware to close those two gaps —
> that's the highest-value thing left, since everything else already
> has real evidence behind it. After that: real garden photos for
> model fine-tuning, since PlantVillage's plain-background images
> don't represent real field conditions."

---

## If asked "is this actually deployed right now?"

> "Yes — that AWS API call in section D just hit the real, live stack.
> It's not a demo environment I spin up for presentations; it's been
> running since I deployed it, and I re-verify it's healthy before any
> demo with a read-only `describe-stacks` call."
