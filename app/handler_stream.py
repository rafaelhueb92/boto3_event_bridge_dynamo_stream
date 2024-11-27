import json
import boto3
from botocore.exceptions import ClientError

eventbridge = boto3.client('events')

def lambda_handler(event, context):
    identification = event.get("identification")
    cron_expression = event.get("cron")

    if not identification or not cron_expression:
        return {"statusCode": 400, "body": json.dumps("Missing 'identification' or 'cron' in payload.")}

    rule_name = f"trigger_process_lambda_{identification}"

    try:
        # Create the EventBridge rule with the cron schedule
        rule_response = eventbridge.put_rule(
            Name=rule_name,
            ScheduleExpression=cron_expression,
            State="ENABLED"
        )

        # Add the target Lambda to the rule
        target_lambda_arn = "arn:aws:lambda:REGION:ACCOUNT_ID:function:process_lambda"
        eventbridge.put_targets(
            Rule=rule_name,
            Targets=[{
                "Id": "1",
                "Arn": target_lambda_arn,
                "Input": json.dumps({"identification": identification})
            }]
        )

        return {
            "statusCode": 200,
            "body": json.dumps(f"EventBridge rule created for {identification}")
        }

    except ClientError as e:
        print(f"Error: {e}")
        return {"statusCode": 500, "body": json.dumps("Error creating EventBridge rule.")}
