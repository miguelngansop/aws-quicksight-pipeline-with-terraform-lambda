import json
import boto3
import pandas as pd
import logging
import os
from io import BytesIO
from quicksight_module import send_csv_to_quicksight


def lambda_handler(event, context):
    # Initialize logging
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)
    CSV_BUCKET = os.environ.get('CSV_BUCKET')

    logger.info('Lambda function started')
    logger.info(f'Event: {event}')
    
    # Your Lambda function code here

    try:
        # Extract bucket name and object key from the S3 event
        s3_event = event['Records'][0]['s3']
        s3_bucket_name = s3_event['bucket']['name']
        s3_object_key = s3_event['object']['key']
        
        # Create an S3 client
        s3_client = boto3.client('s3')
        
        # Retrieve the JSON file from S3
        response = s3_client.get_object(Bucket=s3_bucket_name, Key=s3_object_key)
        json_data = response['Body'].read().decode('utf-8')
        
        # Parse JSON data
        input_data = json.loads(json_data)
        
        # Create a Pandas DataFrame from the JSON data
        df = pd.DataFrame.from_dict(input_data)
        
        # Convert the DataFrame to a CSV string
        csv_data = df.to_csv(index=False)
        
        # Define the S3 object key for the CSV file
        csv_object_key = s3_object_key.replace('.json', '.csv')  # Change file extension
        
        # Save the CSV data to the another S3 bucket
        s3_client.put_object(Bucket=CSV_BUCKET, Key=csv_object_key, Body=csv_data)

        send_csv_to_quicksight(CSV_BUCKET, csv_object_key)
        
        return {
            'statusCode': 200,
            'body': json.dumps('JSON to CSV conversion and saving completed.')
        }
    except Exception as e:
        logger.error(e)
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }
