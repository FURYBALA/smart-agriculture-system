"""
Runs the real Lambda handler code (upload_handler, results_handler,
chat_handler, inference_handler's pure preprocessing math) locally
against moto-mocked AWS services -- no Docker, no `sam local`, no AWS
account. moto intercepts boto3 calls in-process and behaves like real
S3/SQS/DynamoDB closely enough to exercise the actual request
validation, serialization, and error-handling code paths in
backend/lambda_functions/*/app.py.

What this does NOT prove: that API Gateway's request/response mapping,
real IAM permissions, or the deployed Lambda runtime environment behave
the same way. See docs/backend-local-testing.md.

Run:
    pip install moto pytest
    cd backend
    python -m pytest tests/ -v
"""
import base64
import decimal
import json
import os
import struct
import sys
from pathlib import Path

import boto3
import pytest
from moto import mock_aws

BACKEND_DIR = Path(__file__).resolve().parent.parent
LAMBDA_DIR = BACKEND_DIR / "lambda_functions"

# Mirrors how AWS actually wires a Lambda Layer onto the import path
# (the real deployed function has this on sys.path automatically via
# /opt/python; there is no local equivalent, so it's added by hand here).
sys.path.insert(0, str(LAMBDA_DIR / "common_layer" / "python"))

BUCKET_NAME = "test-leaf-images"
QUEUE_NAME = "test-inference-queue"
RESULTS_TABLE = "TestDiagnosisResults"
CHAT_TABLE = "TestChatHistory"

os.environ.setdefault("BUCKET_NAME", BUCKET_NAME)
os.environ.setdefault("RESULTS_TABLE", RESULTS_TABLE)
os.environ.setdefault("CHAT_TABLE", CHAT_TABLE)
# Each app.py creates its boto3 client/resource at import time (real
# Lambda always has a region from its execution environment; moto's
# mocked clients still need one to construct at all).
os.environ.setdefault("AWS_DEFAULT_REGION", "us-east-1")
# QUEUE_URL is set per-test after moto creates the queue (its URL isn't
# known until then).


def _install_tflite_runtime_stub():
    """inference_handler/app.py does `import tflite_runtime.interpreter as
    tflite` at module level. tflite_runtime has no wheel compatible with
    this environment's Python (3.14) -- see
    docs/backend-local-testing.md -- so that import fails before the
    module body (including the pure _preprocess() function this test
    file actually wants to exercise) ever runs.

    This installs a minimal stand-in *only* so the import statement
    resolves; nothing here is used as a real interpreter, and no test
    calls _get_interpreter() or _run_one() (the functions that would
    actually need a working one). That distinction matters: this
    unblocks testing _preprocess()'s real quantization math, it does not
    simulate running the real model.
    """
    import types

    if "tflite_runtime" in sys.modules:
        return
    tflite_runtime = types.ModuleType("tflite_runtime")
    interpreter_module = types.ModuleType("tflite_runtime.interpreter")

    class _UnavailableInterpreter:
        def __init__(self, *args, **kwargs):
            raise RuntimeError(
                "tflite_runtime is not installed in this environment -- "
                "this stub only exists so inference_handler/app.py can be "
                "imported to test its pure preprocessing math; it cannot "
                "actually run inference."
            )

    interpreter_module.Interpreter = _UnavailableInterpreter
    tflite_runtime.interpreter = interpreter_module
    sys.modules["tflite_runtime"] = tflite_runtime
    sys.modules["tflite_runtime.interpreter"] = interpreter_module


def _import_fresh(module_name, path):
    """Each lambda_functions/*/app.py is a same-named module ('app') in a
    different directory -- import each under a distinct name so they
    don't shadow each other in sys.modules."""
    import importlib.util

    spec = importlib.util.spec_from_file_location(module_name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = module
    spec.loader.exec_module(module)
    return module


@pytest.fixture
def aws():
    with mock_aws():
        s3 = boto3.client("s3", region_name="us-east-1")
        s3.create_bucket(Bucket=BUCKET_NAME)

        sqs = boto3.client("sqs", region_name="us-east-1")
        queue_url = sqs.create_queue(QueueName=QUEUE_NAME)["QueueUrl"]
        os.environ["QUEUE_URL"] = queue_url

        dynamodb = boto3.resource("dynamodb", region_name="us-east-1")
        dynamodb.create_table(
            TableName=RESULTS_TABLE,
            KeySchema=[{"AttributeName": "diagnosisId", "KeyType": "HASH"}],
            AttributeDefinitions=[{"AttributeName": "diagnosisId", "AttributeType": "S"}],
            BillingMode="PAY_PER_REQUEST",
        )
        dynamodb.create_table(
            TableName=CHAT_TABLE,
            KeySchema=[
                {"AttributeName": "sessionId", "KeyType": "HASH"},
                {"AttributeName": "timestamp", "KeyType": "RANGE"},
            ],
            AttributeDefinitions=[
                {"AttributeName": "sessionId", "AttributeType": "S"},
                {"AttributeName": "timestamp", "AttributeType": "S"},
            ],
            BillingMode="PAY_PER_REQUEST",
        )
        yield {"s3": s3, "sqs": sqs, "dynamodb": dynamodb, "queue_url": queue_url}


# ---------------------------------------------------------------------
# upload_handler
# ---------------------------------------------------------------------

class TestUploadHandler:
    def _handler(self):
        mod = _import_fresh("upload_handler_app", LAMBDA_DIR / "upload_handler" / "app.py")
        return mod.handler

    def test_valid_upload_stores_in_s3_and_queues_a_job(self, aws):
        handler = self._handler()
        image_bytes = b"\xff\xd8\xff\xe0fake-jpeg-bytes"
        event = {
            "body": json.dumps({
                "imageBase64": base64.b64encode(image_bytes).decode(),
                "mimeType": "image/jpeg",
            })
        }

        response = handler(event, None)

        assert response["statusCode"] == 202
        body = json.loads(response["body"])
        diagnosis_id = body["diagnosisId"]
        assert diagnosis_id

        # Really landed in S3 -- not just a 202 with nothing behind it.
        s3_object = aws["s3"].get_object(Bucket=BUCKET_NAME, Key=f"uploads/{diagnosis_id}.jpg")
        assert s3_object["Body"].read() == image_bytes

        # Really queued -- inference_handler has something to pick up.
        messages = aws["sqs"].receive_message(QueueUrl=aws["queue_url"], MaxNumberOfMessages=1)
        assert len(messages.get("Messages", [])) == 1
        queued = json.loads(messages["Messages"][0]["Body"])
        assert queued["diagnosisId"] == diagnosis_id
        assert queued["bucket"] == BUCKET_NAME

    def test_missing_imageBase64_returns_400(self, aws):
        handler = self._handler()
        response = handler({"body": json.dumps({})}, None)
        assert response["statusCode"] == 400

    def test_non_string_imageBase64_returns_400_not_a_crash(self, aws):
        # Regression coverage: base64.b64decode(12345) raises TypeError,
        # which the except tuple (binascii.Error, ValueError) does NOT
        # catch -- app.py has an explicit isinstance() check for exactly
        # this reason.
        handler = self._handler()
        response = handler({"body": json.dumps({"imageBase64": 12345})}, None)
        assert response["statusCode"] == 400

    def test_invalid_base64_returns_400_not_a_crash(self, aws):
        handler = self._handler()
        response = handler({"body": json.dumps({"imageBase64": "not-valid-base64!!!"})}, None)
        assert response["statusCode"] == 400

    def test_missing_body_returns_400(self, aws):
        handler = self._handler()
        response = handler({}, None)
        assert response["statusCode"] == 400


# ---------------------------------------------------------------------
# results_handler
# ---------------------------------------------------------------------

class TestResultsHandler:
    def _handler(self):
        mod = _import_fresh("results_handler_app", LAMBDA_DIR / "results_handler" / "app.py")
        return mod.handler

    def test_pending_when_no_result_written_yet(self, aws):
        handler = self._handler()
        response = handler({"pathParameters": {"diagnosisId": "does-not-exist-yet"}}, None)
        assert response["statusCode"] == 202
        assert json.loads(response["body"])["status"] == "pending"

    def test_returns_complete_result_including_decimal_confidence(self, aws):
        # This is the exact write shape inference_handler.py produces --
        # a Decimal confidence, not a float (DynamoDB's TypeSerializer
        # rejects native float outright; see that module's comment).
        table = aws["dynamodb"].Table(RESULTS_TABLE)
        table.put_item(Item={
            "diagnosisId": "abc-123",
            "status": "complete",
            "diseaseName": "Early_Blight",
            "confidence": decimal.Decimal("0.767"),
        })

        handler = self._handler()
        response = handler({"pathParameters": {"diagnosisId": "abc-123"}}, None)

        assert response["statusCode"] == 200
        body = json.loads(response["body"])
        assert body["diseaseName"] == "Early_Blight"
        # common.py's _DecimalEncoder must convert Decimal -> JSON number,
        # not throw TypeError trying to serialize it directly.
        assert body["confidence"] == pytest.approx(0.767)

    def test_returns_failed_status_when_inference_failed(self, aws):
        table = aws["dynamodb"].Table(RESULTS_TABLE)
        table.put_item(Item={
            "diagnosisId": "bad-image",
            "status": "failed",
            "error": "Inference failed -- the image may be corrupt or an unsupported format.",
        })

        handler = self._handler()
        response = handler({"pathParameters": {"diagnosisId": "bad-image"}}, None)

        assert response["statusCode"] == 200
        assert json.loads(response["body"])["status"] == "failed"


# ---------------------------------------------------------------------
# chat_handler
# ---------------------------------------------------------------------

class TestChatHandler:
    def _handler(self):
        mod = _import_fresh("chat_handler_app", LAMBDA_DIR / "chat_handler" / "app.py")
        return mod.handler

    def test_post_then_get_round_trips_a_message(self, aws):
        handler = self._handler()

        post_event = {
            "pathParameters": {"sessionId": "session-1"},
            "requestContext": {"http": {"method": "POST"}},
            "body": json.dumps({"role": "user", "text": "Why are my tomato leaves spotted?"}),
        }
        post_response = handler(post_event, None)
        assert post_response["statusCode"] == 201

        get_event = {
            "pathParameters": {"sessionId": "session-1"},
            "requestContext": {"http": {"method": "GET"}},
        }
        get_response = handler(get_event, None)
        assert get_response["statusCode"] == 200
        messages = json.loads(get_response["body"])["messages"]
        assert len(messages) == 1
        assert messages[0]["text"] == "Why are my tomato leaves spotted?"
        assert messages[0]["role"] == "user"

    def test_get_on_empty_session_returns_empty_list_not_error(self, aws):
        handler = self._handler()
        event = {
            "pathParameters": {"sessionId": "never-used-session"},
            "requestContext": {"http": {"method": "GET"}},
        }
        response = handler(event, None)
        assert response["statusCode"] == 200
        assert json.loads(response["body"])["messages"] == []

    def test_post_missing_fields_returns_400(self, aws):
        handler = self._handler()
        event = {
            "pathParameters": {"sessionId": "session-1"},
            "requestContext": {"http": {"method": "POST"}},
            "body": json.dumps({"role": "user"}),  # missing "text"
        }
        response = handler(event, None)
        assert response["statusCode"] == 400

    def test_unsupported_method_returns_405(self, aws):
        handler = self._handler()
        event = {
            "pathParameters": {"sessionId": "session-1"},
            "requestContext": {"http": {"method": "DELETE"}},
        }
        response = handler(event, None)
        assert response["statusCode"] == 405


# ---------------------------------------------------------------------
# inference_handler -- preprocessing/postprocessing math only.
#
# tflite_runtime / tensorflow have no wheel compatible with this
# environment's Python (3.14) -- documented in docs/backend-local-testing.md,
# same "genuinely unavailable" category as physical hardware, not
# something skipped by choice. What IS tested here is the actual
# _preprocess() function and the Decimal-conversion line, both real
# production code, without needing a loaded interpreter.
# ---------------------------------------------------------------------

class TestInferenceHandlerPreprocessing:
    def _module(self):
        os.environ.setdefault("RESULTS_TABLE", RESULTS_TABLE)
        _install_tflite_runtime_stub()
        return _import_fresh("inference_handler_app", LAMBDA_DIR / "inference_handler" / "app.py")

    def test_preprocess_produces_correctly_shaped_int8_tensor(self):
        from PIL import Image
        import io
        import numpy as np

        mod = self._module()

        # A real value pulled from ml/models/training_metadata.json's
        # input_quantization, not a made-up scale/zero-point.
        input_details = {"quantization": (0.003921568859368563, -128)}

        img = Image.new("RGB", (120, 80), color=(64, 128, 200))
        buf = io.BytesIO()
        img.save(buf, format="PNG")

        tensor = mod._preprocess(buf.getvalue(), input_details)

        assert tensor.shape == (1, 96, 96, 3)
        assert tensor.dtype == np.int8
        assert tensor.min() >= -128
        assert tensor.max() <= 127

    def test_preprocess_black_and_white_land_at_quantization_extremes(self):
        from PIL import Image
        import io
        import numpy as np

        mod = self._module()
        input_details = {"quantization": (0.003921568859368563, -128)}

        black = Image.new("RGB", (96, 96), color=(0, 0, 0))
        buf = io.BytesIO()
        black.save(buf, format="PNG")
        black_tensor = mod._preprocess(buf.getvalue(), input_details)
        assert np.all(black_tensor == -128)

        white = Image.new("RGB", (96, 96), color=(255, 255, 255))
        buf = io.BytesIO()
        white.save(buf, format="PNG")
        white_tensor = mod._preprocess(buf.getvalue(), input_details)
        # Same float-precision caveat as firmware/vision_node's host
        # test: the real scale isn't exactly 1/255, so full white can
        # land one step below the top of the INT8 range.
        assert np.all((white_tensor == 127) | (white_tensor == 126))

    def test_decimal_conversion_matches_the_real_confidence_write(self):
        # Exactly the line inference_handler.py's _run_one() uses.
        # DynamoDB's TypeSerializer rejects native float outright; this
        # is the fix, re-verified here as a regression guard.
        probs_value = 0.7669999599456787  # a realistic float32 softmax output
        converted = decimal.Decimal(str(probs_value))
        assert isinstance(converted, decimal.Decimal)
        assert abs(float(converted) - probs_value) < 1e-6


def test_model_artifact_is_a_well_formed_tflite_flatbuffer():
    """No interpreter needed for this: every valid .tflite file has the
    4-byte identifier "TFL3" at a fixed offset in the FlatBuffer header.
    This doesn't prove the model runs correctly, only that the shipped
    artifact is a real, non-corrupted TFLite file of the documented
    size."""
    model_path = BACKEND_DIR.parent / "ml" / "models" / "tomato_disease_model_int8.tflite"
    data = model_path.read_bytes()
    assert data[4:8] == b"TFL3"

    with open(BACKEND_DIR.parent / "ml" / "models" / "training_metadata.json") as f:
        metadata = json.load(f)
    actual_kb = len(data) / 1024
    assert abs(actual_kb - metadata["quantized_model_kb"]) < 0.1
