"""RTDA - placeholder handler for the fraud-event Lambda.

Replace this with the real implementation (deployed via pipeline / S3 package).
On a detected fraud event it should emit a new event to the banking core and
publish a notification to the SNS topic referenced by the SNS_TOPIC_ARN env var.
"""


def lambda_handler(event, context):
    return {"status": "placeholder", "received": event}
