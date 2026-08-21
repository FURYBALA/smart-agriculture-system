"""
POST /diagnose
Accepts a base64-encoded leaf image, stores it in S3, and queues an
inference job. Returns immediately with a diagnosisId the client polls
via GET /diagnose/{diagnosisId} (results_handler) -- inference runs
asynchronously off the request path so a slow model doesn't hold the
API Gateway connection open.

Request body (JSON):
  { "imageBase64": "...", "mimeType": "image/jpeg" }

Response (202):
  { "diagnosisId": "..." }
"""
import base64
import binascii
import json
import os
import uuid

import boto3
from common import json_response

s3 = boto3.client("s3")
sqs = boto3.client("sqs")

BUCKET_NAME = os.environ["BUCKET_NAME"]
QUEUE_URL = os.environ["QUEUE_URL"]

EXTENSION_BY_MIME = {
    "image/jpeg": "jpg",
    "image/png": "png",
}


def handler(event, context):
    try:
        body = json.loads(event.get("body") or "{}")
        image_b64 = body["imageBase64"]
        mime_type = body.get("mimeType", "image/jpeg")
    except (KeyError, json.JSONDecodeError):
        return json_response(400, {"error": "expected JSON body with imageBase64"})

    # b64decode raises TypeError (not caught below) if imageBase64 is
    # valid JSON but not a string -- e.g. a client sending the number
    # 12345 instead of a base64 string. Reject that explicitly rather
    # than relying on the decode call to catch every wrong input shape.
    if not isinstance(image_b64, str):
        return json_response(400, {"error": "imageBase64 must be a string"})

    try:
        image_bytes = base64.b64decode(image_b64, validate=True)
    except (binascii.Error, ValueError):
        return json_response(400, {"error": "imageBase64 is not valid base64"})

    extension = EXTENSION_BY_MIME.get(mime_type, "jpg")
    diagnosis_id = str(uuid.uuid4())
    s3_key = f"uploads/{diagnosis_id}.{extension}"

    s3.put_object(Bucket=BUCKET_NAME, Key=s3_key, Body=image_bytes, ContentType=mime_type)

    sqs.send_message(
        QueueUrl=QUEUE_URL,
        MessageBody=json.dumps({
            "diagnosisId": diagnosis_id,
            "bucket": BUCKET_NAME,
            "key": s3_key,
        }),
    )

    return json_response(202, {"diagnosisId": diagnosis_id})
