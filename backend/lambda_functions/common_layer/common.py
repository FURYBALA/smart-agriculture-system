"""
Shared helpers for the Lambda functions in this backend. Packaged as
a Lambda Layer (see infrastructure/template.yaml, CommonLayer) so all
four functions import the same code instead of each keeping its own
copy -- a change to the response shape (e.g. adding CORS headers)
only needs to happen once.
"""
import json
from decimal import Decimal


class _DecimalEncoder(json.JSONEncoder):
    """DynamoDB has no native float type -- boto3's resource API
    returns numeric attributes (e.g. inference_handler's `confidence`)
    as Decimal, which plain json.dumps() can't serialize and raises
    TypeError on. Any handler returning an item read from DynamoDB
    needs this, not just the ones that happen to have been tested
    against a numeric field."""

    def default(self, o):
        if isinstance(o, Decimal):
            return float(o)
        return super().default(o)


def json_response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body, cls=_DecimalEncoder),
    }
