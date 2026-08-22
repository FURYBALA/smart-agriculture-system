# Cloud Backend

Matches the cloud architecture in the project report's Figure 3.3:
API Gateway -> S3 (image storage) -> SQS -> Lambda inference ->
DynamoDB (results + chat history), defined as an AWS SAM template.

**Deployed and verified.** This backend was actually deployed to AWS
(account `273422285791`, region `ap-south-1`, CloudFormation stack
`smart-agriculture-system`, via a one-off manual GitHub Actions
workflow -- see [`docs/DEPLOYMENT.md`](../docs/DEPLOYMENT.md#deployed-instance)
for the full record). All 21 resources reached `CREATE_COMPLETE`, and a
real end-to-end smoke test -- upload → S3 → SQS → real INT8 model
inference → DynamoDB → poll → `complete` -- succeeded against the live
API, along with the chat endpoints. Deploying your own copy still
creates billable AWS resources in your account; the steps below are
unchanged and still apply for that.

## Deployed instance

| | |
|---|---|
| AWS account | `273422285791` |
| Region | `ap-south-1` |
| Stack name | `smart-agriculture-system` |
| Deployed via | [`.github/workflows/deploy-aws.yml`](../.github/workflows/deploy-aws.yml) (manual `workflow_dispatch` only -- never runs automatically) |
| API base URL | `https://p17huf2s49.execute-api.ap-south-1.amazonaws.com/prod/` |
| Stack status | `UPDATE_COMPLETE`, all 21 resources `CREATE_COMPLETE` |
| Real smoke test | `POST /diagnose` with a synthetic test image → `202` with a `diagnosisId` → polled `GET /diagnose/{id}` → `complete` with a real class + confidence from the actual deployed model. `POST`/`GET /chat/{sessionId}` also verified round-tripping through DynamoDB. |

A real deployment bug was found and fixed in the process: the first
deploy attempt's Lambda functions all failed at import with
`No module named 'common'`. The `CommonLayer`'s source had a `python/`
subfolder already (the correct Lambda Layer convention on its own), but
`Metadata: BuildMethod: python3.12` made SAM's builder wrap it in
*another* `python/` prefix during build -- confirmed by downloading and
inspecting the actual deployed layer zip
(`python/python/common.py`, not importable). Fixed by moving
`common.py` up a level so the build step's own prefixing produces the
correct path; this was invisible to all local/CI tests because they
add the layer's source directly to `sys.path`, bypassing SAM's build
step entirely.

This deployment is not automatically kept in sync with future code
changes -- re-run the workflow (or `sam build --use-container && sam
deploy`) after changing backend code if you want the deployed version
to match.

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
# 1. Configure AWS credentials (once)
aws configure   # or: export AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... AWS_DEFAULT_REGION=...

# 2. Build (see "Before deploying" above for the two manual steps first)
pip install aws-sam-cli   # if you don't have it
cd infrastructure
sam build --use-container

# 3. Deploy
sam deploy --guided
```

You'll need an AWS account and configured credentials. `sam deploy --guided`
walks through stack name, region, and confirms the resources before
creating anything -- nothing is created until you approve that prompt.

```bash
# 4. Retrieve the deployed API URL
aws cloudformation describe-stacks --stack-name <the-stack-name-you-chose> \
  --query "Stacks[0].Outputs[?OutputKey=='ApiUrl'].OutputValue" --output text
```

Put that URL into `mobile_app/.env` as `BACKEND_API_URL` if you're using
this backend path instead of (or alongside) Gemini-direct.

```bash
# 5. Smoke-test the deployed API
curl -X POST "<ApiUrl>diagnose" \
  -H "Content-Type: application/json" \
  -d '{"imageBase64":"<base64-encoded-jpeg>","mimeType":"image/jpeg"}'
# -> {"diagnosisId": "..."}, then:
curl "<ApiUrl>diagnose/<diagnosisId>"
# -> {"status": "pending"} at first, then {"status": "complete", "diseaseName": "...", "confidence": ...}
```

## Tearing down

```bash
sam delete --stack-name <the-stack-name-you-chose>
```
Removes every resource the stack created (Lambda functions, API Gateway,
S3 bucket, SQS queue, DynamoDB tables). The S3 bucket has a 90-day
image-expiry lifecycle rule but isn't emptied automatically by
`sam delete` if it still has objects in it -- empty it first
(`aws s3 rm s3://<bucket-name> --recursive`) if deletion fails on that
account.

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
