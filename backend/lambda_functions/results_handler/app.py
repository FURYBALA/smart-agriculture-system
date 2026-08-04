"""
GET /diagnose/{diagnosisId}
Polled by the client after POST /diagnose (upload_handler) returns a
diagnosisId. Returns 202 + {"status": "pending"} while inference_handler
hasn't finished yet, or 200 with the full result once it has.
"""
import json
import os

import boto3

dynamodb = boto3.resource("dynamodb")
RESULTS_TABLE = os.environ["RESULTS_TABLE"]


def handler(event, context):
    diagnosis_id = event["pathParameters"]["diagnosisId"]
    table = dynamodb.Table(RESULTS_TABLE)

    item = table.get_item(Key={"diagnosisId": diagnosis_id}).get("Item")
    if item is None:
        return _response(202, {"status": "pending"})

    return _response(200, item)


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }
