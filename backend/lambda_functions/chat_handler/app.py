"""
GET  /chat/{sessionId}  -> full message history for that session
POST /chat/{sessionId}  -> append one message: { "role": "user"|"assistant", "text": "..." }

This is server-side history sync for the chatbot (so a conversation
survives an app reinstall or a second device) -- it does not call
Gemini itself. The app talks to Gemini directly (see
mobile_app/lib/services/gemini_service.dart) and writes each turn here
afterward.
"""
import json
import os
import time

import boto3
from boto3.dynamodb.conditions import Key
from common import json_response

dynamodb = boto3.resource("dynamodb")
CHAT_TABLE = os.environ["CHAT_TABLE"]


def handler(event, context):
    session_id = event["pathParameters"]["sessionId"]
    table = dynamodb.Table(CHAT_TABLE)
    method = event["requestContext"]["http"]["method"] if "http" in event.get("requestContext", {}) \
        else event.get("httpMethod")

    if method == "GET":
        rows = table.query(KeyConditionExpression=Key("sessionId").eq(session_id))
        return json_response(200, {"messages": rows.get("Items", [])})

    if method == "POST":
        try:
            body = json.loads(event.get("body") or "{}")
            role = body["role"]
            text = body["text"]
        except (KeyError, json.JSONDecodeError):
            return json_response(400, {"error": "expected JSON body with role and text"})

        table.put_item(Item={
            "sessionId": session_id,
            "timestamp": str(time.time()),
            "role": role,
            "text": text,
        })
        return json_response(201, {"status": "saved"})

    return json_response(405, {"error": "method not allowed"})
