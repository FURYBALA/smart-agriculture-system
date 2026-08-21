# Cloud Backend

Matches the cloud architecture in the project report's Figure 3.3:
API Gateway -> S3 (image storage) -> SQS -> Lambda inference ->
DynamoDB (results + chat history), defined as an AWS SAM template.

**Not deployed.** This is real, deployable infrastructure-as-code, not
a mockup -- but nobody has run `sam deploy` on it. Deploying creates
billable AWS resources (Lambda, API Gateway, S3, DynamoDB, SQS).

## Why this exists alongside Gemini Vision

The mobile app's primary diagnosis path calls Gemini Vision directly
from the phone (`mobile_app/lib/services/gemini_service.dart`) and
needs no backend at all -- that's simpler and is what actually runs
today. This backend is the alternative the report's architecture
diagram describes: your own model, behind your own API, with your own
results/history storage, instead of depending on a third-party vision
API. Use it if you want that independence; skip it if Gemini directly
from the app is enough.

## Architecture

```
Flutter app --POST /diagnose (image)--> API Gateway --> upload_handler
                                                            |
                                                    stores in S3, queues job
                                                            |
                                                            v
                                                      SQS queue --> inference_handler
                                                                    (loads the same
                                                                     .tflite model
                                                                     used on-device)
                                                                          |
                                                                write result to
                                                                          |
                                                                          v
Flutter app --GET /diagnose/{id}--> API Gateway --> results_handler --> DynamoDB

Flutter app --GET/POST /chat/{sessionId}--> API Gateway --> chat_handler --> DynamoDB
```

## Before deploying

1. **Copy the trained model into the inference function**:
   ```bash
   cp ../ml/models/tomato_disease_model_int8.tflite lambda_functions/inference_handler/
   ```
2. **Update `CLASS_LABELS`** in `lambda_functions/inference_handler/app.py`
   to match the exact order in `ml/models/training_metadata.json`
   (`class_names`) -- getting this order wrong silently mislabels every
   prediction.
3. **`ai-edge-litert` packaging** (the TFLite interpreter package this
   uses -- see the note in `app.py`: the original `tflite-runtime`
   package has been removed from PyPI entirely): it ships native
   binaries that must match Lambda's execution environment (manylinux,
   correct architecture). `sam build` with a container
   (`sam build --use-container`) handles this correctly; installing the
   wheel locally on Windows/macOS and zipping it up will not work.

## Deploying

```bash
pip install aws-sam-cli   # if you don't have it
cd infrastructure
sam build --use-container
sam deploy --guided
```

You'll need an AWS account and configured credentials. `sam deploy --guided`
walks through stack name, region, and confirms the resources before
creating anything.

## Local testing without AWS

**With Docker** (not available in this project's dev environment --
untested here, but this is the standard SAM workflow):
```bash
sam local start-api
```
Runs the API Gateway + Lambda locally via Docker for testing the HTTP
contract before deploying for real.

**Without Docker** -- what this repo actually has: `sam validate`,
`sam build` for three of the four functions plus the shared layer, and
the real Lambda handler code exercised directly against
`moto`-mocked S3/SQS/DynamoDB:
```bash
pip install -r requirements-dev.txt
python -m pytest tests/ -v
```
19 tests, all passing -- including real inference through the actual
shipped model (`ai-edge-litert`, not the removed `tflite-runtime`
package, does install locally). Full account of what was checked this
way, what wasn't, and exactly why:
[`docs/backend-local-testing.md`](../docs/backend-local-testing.md).
