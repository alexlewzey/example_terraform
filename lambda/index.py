import boto3
import os
from datetime import datetime

def handler(event, context):
    s3 = boto3.client('s3')
    bucket_name = os.environ['BUCKET_NAME']
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    try:
        response = s3.put_object(
            Bucket=bucket_name,
            Key=f'hello_world_{timestamp}.txt',
            Body=f'Hello mole! it is {timestamp}'
        )
        return response
    except Exception as e:
        print(e)
        raise e
