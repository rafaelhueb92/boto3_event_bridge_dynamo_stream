import json
import boto3
from botocore.exceptions import ClientError

dynamodb = boto3.resource('dynamodb')
table_name = "identification_table"  # Should match the DynamoDB table name created by Terraform
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    identification = event.get("identification")

    if not identification:
        return {"statusCode": 400, "body": json.dumps("Missing 'identification' key in event.")}

    try:
        response = table.get_item(Key={'identification': identification})
        item = response.get('Item')

        if not item:
            return {"statusCode": 404, "body": json.dumps("Item not found.")}

        return {"statusCode": 200, "body": json.dumps(item)}

    except ClientError as e:
        print(f"Error: {e}")
        return {"statusCode": 500, "body": json.dumps("Error retrieving data from DynamoDB.")}
