# Backend local testing

No Docker, no AWS account/credentials, and no `sam local start-api`
(which needs Docker to run the actual Lambda execution environment) are
available in this project's dev environment. This documents what was
actually exercised locally instead, and exactly why the remaining pieces
weren't.

## What was verified

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
to build a Lambda Layer. This was a real, previously-undiscovered gap in
the infrastructure code -- fixed by adding it, then re-verified with a
clean build.

`InferenceHandlerFunction` fails locally with *"Could not satisfy the
requirement: tflite-runtime"* -- `tflite-runtime` ships platform-specific
native binaries, and `pip` running on this Windows host can't resolve a
wheel for it outside a matching Lambda container. This is not a new
finding: `backend/README.md` already documented that
`sam build --use-container` (which builds inside a Docker container
matching Lambda's actual execution environment) is required for this
specific function, and this local run independently confirms that claim
is accurate, not just assumed. Without Docker in this environment,
`--use-container` itself can't be exercised either.

### Real Lambda handlers, via moto (no Docker needed)

`backend/tests/test_lambda_handlers_local.py` imports and calls the
actual `handler(event, context)` functions from `upload_handler`,
`results_handler`, and `chat_handler` directly, with `moto` mocking S3 /
SQS / DynamoDB in-process. This is real request validation, error
handling, and serialization code executing -- not a description of what
it should do.

```bash
pip install -r backend/requirements-dev.txt
cd backend
python -m pytest tests/ -v
```

16 tests, all passing, including:

- a full upload -> S3 object -> SQS message round trip
- the 400 responses for missing/non-string/invalid-base64 `imageBase64`
  (including the specific `TypeError` gap the base64 validation exists
  to catch)
- DynamoDB round-trips for `results_handler`, including a `Decimal`
  confidence value serialized back to JSON correctly
- a full chat POST-then-GET round trip and the 400/405 error paths
- `inference_handler`'s real `_preprocess()` function (image resize,
  normalize, INT8 quantize) against the shipped model's actual
  quantization parameters from `training_metadata.json` -- including a
  black and white image landing at the two ends of the INT8 range
- confirming the model file at `ml/models/tomato_disease_model_int8.tflite`
  is a structurally valid TFLite FlatBuffer of the documented size

### What's NOT covered: real model inference

`inference_handler.py` needs `tflite_runtime` (or `tensorflow`'s
`tf.lite.Interpreter`) to actually run the model. Neither has a wheel
compatible with this environment's Python (3.14) -- confirmed by
attempting the install, not assumed:

```
ERROR: Could not find a version that satisfies the requirement tflite-runtime (from versions: none)
```

Installing full `tensorflow` was not attempted: it's a substantially
larger dependency, Python 3.14 is newer than TensorFlow's typical
supported range, and this project has separately hit Windows
Application/Smart App Control blocking TensorFlow's unsigned native
extensions in this same environment before. This is the same
"genuinely unavailable" category as physical hardware, not something
skipped by choice -- the `_preprocess()` tests above cover the real
quantization math without it, and
`ml/scripts/convert_tflite.py`'s own quantized spot-check (documented in
[`docs/dataset.md`](dataset.md)) is where the real model was actually
run and evaluated, on a machine where TensorFlow was installed.

## What was NOT verified

- `sam local start-api` / actual Lambda execution in a real (or
  Docker-simulated) Lambda runtime
- `sam build --use-container` for `inference_handler`
- Real API Gateway request/response mapping
- Real IAM permissions
- Anything requiring an actual AWS account (`sam deploy`)

See [`backend/README.md`](../backend/README.md) for what deploying for
real requires.
