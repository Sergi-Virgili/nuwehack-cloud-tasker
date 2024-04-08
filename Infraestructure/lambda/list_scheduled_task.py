import json
import boto3

# Inicializa el cliente de DynamoDB
dynamodb = boto3.resource('dynamodb')

def handler(event, context):
    table = dynamodb.Table('TaskTable')

    response = table.scan()

    return {
        'statusCode': 200,
        'body': json.dumps(response['Items']),
        'headers': {
            'Content-Type': 'application/json'
        }
    }