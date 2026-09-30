import json
import csv
import io
import os
import boto3
import uuid
from datetime import datetime

s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

TABLE_NAME = os.environ['DYNAMODB_TABLE']
table = dynamodb.Table(TABLE_NAME)


def handler(event, context):
    print(f"Received event: {json.dumps(event)}")

    detail = event['detail']
    bucket = detail['bucket']['name']
    key = detail['object']['key']

    print(f"Processing s3://{bucket}/{key}")

    try:
        response = s3.get_object(Bucket=bucket, Key=key)
        content = response['Body'].read().decode('utf-8')

        reader = csv.DictReader(io.StringIO(content))
        row_count = 0

        for row in reader:
            item = dict(row)
            item['id'] = str(uuid.uuid4())
            item['ingested_at'] = datetime.utcnow().isoformat()
            item['source_file'] = key

            table.put_item(Item=item)
            row_count += 1

        print(f"Successfully processed {row_count} rows from {key}")

    except Exception as e:
        print(f"ERROR processing {key}: {str(e)}")
        raise e

    return {
        'statusCode': 200,
        'body': json.dumps('Processing complete')
    }
