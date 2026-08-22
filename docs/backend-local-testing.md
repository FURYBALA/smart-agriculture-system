# Backend local testing

No Docker and no AWS account/credentials are available on this project's
local (Windows) dev machine, so `sam local start-api` can't run there.
This documents what was actually exercised locally and in CI, where
GitHub's runners have capabilities (Docker) the local machine doesn't --
and exactly why the remaining pieces weren't, at the local/CI layer.

The backend has since been **actually deployed to a real AWS account**
via a separate, manual GitHub Actions workflow -- that real-AWS
evidence (live API Gateway, real Lambda execution, real DynamoDB
writes) lives in
[`docs/DEPLOYMENT.md`](DEPLOYMENT.md#deployed-instance) and
[`backend/README.md`](../backend/README.md#deployed-instance), not
here. This document is scoped to what local/CI testing alone proved,
without a real AWS account, which is a real and still-relevant category
distinct from the deployment evidence.

## A real dependency bug found and fixed along the way

`inference_handler/app.py` originally imported `tflite_runtime`. While
verifying this locally, `pip index versions tflite-runtime` returned
**no distributions at all** -- not "none for this platform," none
published, period. That package has been removed from PyPI entirely.
This meant `inference_handler` could never have been deployed as
written, in any environment, not just built locally -- a real
deployability bug, not a local-machine limitation. Fixed by switching to
`ai-edge-litert`, Google's drop-in-compatible successor package (same
`Interpreter` API), in both `app.py` and its `requirements.txt`.

## What was verified locally

### `sam validate` / `sam build`

```bash
cd backend/infrastructure
sam validate --lint          # PASS -- valid SAM template
sam build CommonLayer        # PASS (after a real fix -- see below)
sam build UploadHandlerFunction    # PASS
sam build ResultsHandlerFunction   # PASS
sam build ChatHandlerFunction      # PASS
sam build InferenceHandlerFunction # FAILS locally -- see below, expected
```

Building `CommonLayer` failed on the first attempt: *"Build method
missing in layer CommonLayer."* `template.yaml`'s `CommonLayer` resource
was missing the `Metadata: BuildMethod: python3.12` property SAM needs
to build a Lambda Layer. Fixed by adding it, then re-verified with a
clean build.

`InferenceHandlerFunction` still fails with a **plain** local `sam build`
(no container): `ai-edge-litert`, like the package it replaced, ships
platform-specific native binaries that plain `pip` on this Windows host
can't resolve a matching wheel for outside a Lambda-matching container.
`sam build --use-container` is the documented fix for that
(`backend/README.md`) -- Docker isn't available locally to exercise it,
but see the CI section below, where it is.

### Real Lambda handlers, via moto (no Docker needed)

`backend/tests/test_lambda_handlers_local.py` imports and calls the
actual `handler(event, context)` functions from `upload_handler`,
`results_handler`, and `chat_handler` directly, with `moto` mocking S3 /
SQS / DynamoDB in-process -- real request validation, error handling,
and serialization code executing, not a description of what it should
do.

```bash
pip install -r backend/requirements-dev.txt
cd backend
python -m pytest tests/ -v
```

19 tests, all passing, including:

- a full upload -> S3 object -> SQS message round trip
- the 400 responses for missing/non-string/invalid-base64 `imageBase64`
  (including the specific `TypeError` gap the base64 validation exists
  to catch)
- DynamoDB round-trips for `results_handler`, including a `Decimal`
  confidence value serialized back to JSON correctly
- a full chat POST-then-GET round trip and the 400/405 error paths
- confirming the model file at `ml/models/tomato_disease_model_int8.tflite`
  is a structurally valid TFLite FlatBuffer of the documented size

### Real model inference -- not just preprocessing math

Unlike everything else ML-related in this audit, real interpreter-based
inference **was** verified locally, once `ai-edge-litert` turned out to
actually install here (unlike the old `tflite-runtime`):

- `interpreter.get_input_details()`/`get_output_details()` on the real
  loaded model match `training_metadata.json`'s documented
  `input_quantization` and 8-class output shape exactly -- not assumed
  consistent, checked against the live interpreter.
- `_preprocess()` (image resize, normalize, INT8 quantize) tested
  against the shipped model's real quantization parameters, including a
  black and white image landing at the two ends of the INT8 range.
- `_run_one()` -- the real end-to-end function: S3 read, preprocess,
  `interpreter.invoke()`, DynamoDB write -- run against a synthetic test
  image with `moto`-mocked S3/DynamoDB. It returns one of the model's
  actual 8 classes with a confidence in `[0, 1]`. This proves the
  *pipeline* is wired correctly end-to-end through a real interpreter
  call; it is **not** a claim that the prediction is correct for that
  image -- there's no real diseased-leaf photo in this environment to
  test against (the PlantVillage dataset directory is gitignored and
  wasn't re-downloaded for this). Real accuracy numbers come from
  `ml/scripts/convert_tflite.py`'s quantized spot-check against real
  PlantVillage images, documented in [`docs/dataset.md`](dataset.md).
- A corrupt/non-image S3 object correctly raises rather than silently
  writing a bogus result -- `handler()`'s try/except (not exercised in
  this specific test) is what turns that into a `status: "failed"`
  DynamoDB write for the real Lambda entry point.

### Backend CI (`.github/workflows/backend-ci.yml`) -- confirmed, not assumed

GitHub's `ubuntu-latest` runners have Docker, which this local machine
doesn't. CI runs the same `pytest` suite plus `sam build
--use-container` for the *entire* stack, including
`InferenceHandlerFunction` -- the one function that can't build locally.
Checked the actual run rather than assuming it would pass: both jobs
succeeded, and the build log shows `Build Succeeded` for
`InferenceHandlerFunction` specifically, with `ai-edge-litert-2.2.0-cp312-cp312-manylinux_2_27_x86_64.whl`
resolving cleanly inside the container. So `sam build --use-container`
for the complete stack is now real, CI-verified evidence, not a
documented-but-unexercised claim -- check the workflow's latest run to
confirm it's still current.

## What was NOT verified locally or in CI, but has since been verified against real AWS

- Real Lambda execution behind a real API Gateway
- Real API Gateway request/response mapping
- The full deploy path (`sam deploy` against a real account)

These are now covered by the real deployment (`docs/DEPLOYMENT.md`,
`backend/README.md`) -- included here only so this document doesn't read
as still-current on those specific points.

## What remains unverified, period

- `sam local start-api` specifically (Docker-simulated API Gateway) --
  superseded by testing against the real deployed API instead, never
  run itself
- IAM policies' tight-scoping (the deploy succeeded with the configured
  policies; whether they're minimal, not just sufficient, wasn't
  separately audited)
- The model's prediction *accuracy* on any real leaf photo in this
  specific test run (real accuracy is `docs/dataset.md`'s domain, using
  real PlantVillage images, not this pipeline-wiring test's synthetic
  one)

See [`backend/README.md`](../backend/README.md) for deployment details.
