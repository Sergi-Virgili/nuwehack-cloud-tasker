import json
import boto3
from datetime import datetime

s3 = boto3.client('s3')

def handler(event, context):
    bucket_name = 'taskstorage'
    
    file_name = f'task_{datetime.now().isoformat()}.txt'
    file_content = 'Este es un item creado por executeScheduledTask.'
    
    s3.put_object(Bucket=bucket_name, Key=file_name, Body=file_content)
    
    return {
        'statusCode': 200,
        'body': json.dumps('Archivo creado exitosamente en S3.')
    }