"""
SQS-triggered. Downloads the uploaded leaf image from S3, runs it
through the same INT8 TFLite tomato-disease model used on the ESP32-CAM
(ml/models/tomato_disease_model_int8.tflite, packaged alongside this
function -- see backend/README.md for how it gets there), and writes
the result to DynamoDB for results_handler to serve.

This mirrors the report's cloud "AI Inference Service" block. The
production app in this project actually calls Gemini Vision directly
from the phone for the primary diagnosis flow (see
mobile_app/lib/services/gemini_service.dart) since that needs no
backend at all; this queue-based path is what you'd use instead if you
wanted a single first-party model behind your own API rather than a
third-party vision API, matching the report's original architecture
diagram.
"""
import io
import json
import os

import boto3
import numpy as np
from PIL import Image
import tflite_runtime.interpreter as tflite

s3 = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")

RESULTS_TABLE = os.environ["RESULTS_TABLE"]
MODEL_PATH = os.path.join(os.path.dirname(__file__), "tomato_disease_model_int8.tflite")

CLASS_LABELS = [
    "Bacterial_Spot",
    "Early_Blight",
    "Healthy",
    "Late_Blight",
    "Septoria_Leaf_Spot",
    "Spider_Mite",
    "TYLCV",
    "Target_Spot",
]  # NOTE: keep in sync with ml/models/training_metadata.json class_names order

_interpreter = None


def _get_interpreter():
    global _interpreter
    if _interpreter is None:
        _interpreter = tflite.Interpreter(model_path=MODEL_PATH)
        _interpreter.allocate_tensors()
    return _interpreter


def _preprocess(image_bytes, input_details):
    img = Image.open(io.BytesIO(image_bytes)).convert("RGB").resize((96, 96))
    arr = np.asarray(img, dtype=np.float32) / 255.0

    scale, zero_point = input_details["quantization"]
    arr = arr / scale + zero_point
    arr = np.clip(arr, -128, 127).astype(np.int8)
    return np.expand_dims(arr, axis=0)


def handler(event, context):
    table = dynamodb.Table(RESULTS_TABLE)

    for record in event["Records"]:
        message = json.loads(record["body"])
        diagnosis_id = message["diagnosisId"]
        bucket = message["bucket"]
        key = message["key"]

        obj = s3.get_object(Bucket=bucket, Key=key)
        image_bytes = obj["Body"].read()

        interpreter = _get_interpreter()
        input_details = interpreter.get_input_details()[0]
        output_details = interpreter.get_output_details()[0]

        interpreter.set_tensor(input_details["index"], _preprocess(image_bytes, input_details))
        interpreter.invoke()
        output = interpreter.get_tensor(output_details["index"])[0]

        out_scale, out_zero_point = output_details["quantization"]
        probs = (output.astype(np.float32) - out_zero_point) * out_scale
        best_idx = int(np.argmax(probs))

        table.put_item(Item={
            "diagnosisId": diagnosis_id,
            "status": "complete",
            "diseaseName": CLASS_LABELS[best_idx],
            "confidence": float(probs[best_idx]),
        })

    return {"statusCode": 200}
