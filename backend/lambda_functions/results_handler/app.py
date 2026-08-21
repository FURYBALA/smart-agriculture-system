"""
GET /diagnose/{diagnosisId}
Polled by the client after POST /diagnose (upload_handler) returns a
diagnosisId. Returns 202 + {"status": "pending"} while inference_handler
hasn't finished yet, or 200 with the full result once it has (including
{"status": "failed", "error": "..."} if inference_handler couldn't
process the image).
"""
import os

import boto3
from common import json_response

dynamodb = boto3.resource("dynamodb")
RESULTS_TABLE = os.environ["RESULTS_TABLE"]


def handler(event, context):
    diagnosis_id = event["pathParameters"]["diagnosisId"]
    table = dynamodb.Table(RESULTS_TABLE)

    item = table.get_item(Key={"diagnosisId": diagnosis_id}).get("Item")
    if item is None:
        return json_response(202, {"status": "pending"})

    return json_response(200, item)
