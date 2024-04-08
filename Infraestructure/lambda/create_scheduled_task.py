import json
import uuid
import boto3

def handler(event, context):
    body = json.loads(event['body'])
    task_name = body['task_name']
    cron_expression = body['cron_expression']

    task_id = str(uuid.uuid4())

    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('TaskTable') 


    table.put_item(
       Item={
            'task_id': task_id,
            'task_name': task_name,
            'cron_expression': cron_expression
        }
    )

    return {
        'statusCode': 200,
        'body': json.dumps({'task_id': task_id})
    }