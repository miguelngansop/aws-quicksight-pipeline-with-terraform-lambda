from ast import Try
import boto3
import pandas as pd
import os
import logging
import json
import uuid

AWS_ACCOUNT_ID = os.environ.get('AWS_ACCOUNT_ID')
logger = logging.getLogger()
logger.setLevel(logging.INFO)
# Initialize the QuickSight client
quicksight = boto3.client('quicksight')

def send_csv_to_quicksight(bucket_name, csv_key):
    
    logger.info('Lambda send_csv_to_quicksight started')

    #Generate a manifest file and upload it to S3
    manifest_key = csv_key.replace('.csv', '.manifest')
    generate_and_upload_manifest(bucket_name, csv_key, manifest_key)
    
    # Create a QuickSight dataset and send the CSV
    response_data_set = create_quicksight_dataset(bucket_name, csv_key,manifest_key )
    # Create a QuickSight ingesting to send the CSV data the dataset
    send_csv_to_dataset(response_data_set['DataSetId'])
    # Create a QuickSight analysis
    analysis_name = manifest_key.replace('.manifest', " Analysis").upper()
    data_source_placeholder = manifest_key.replace('.manifest', " Data Source ").upper()
    create_analysis(response_data_set['Arn'], analysis_name, data_source_placeholder)

# Function to create the dataset
def create_quicksight_dataset(bucket_name, csv_key, manifest_key):
        # Define the data source configuration
        data_source_name = manifest_key.replace(".manifest", "DSET")
        data_source_config = {
            'DataSourceId': str(uuid.uuid4()),
            'Name': data_source_name.upper() ,
            'Type': 'S3',
            'DataSourceParameters': {
                'S3Parameters': {
                    'ManifestFileLocation': {
                        'Bucket': bucket_name,
                        'Key': f'{manifest_key}'
                        }
                    }
                }
        }
        logger.info(f'lets start creating the datasource: bucket - {bucket_name} - csv_key - {manifest_key}')
        # Create the data source
        result_datasource = quicksight.create_data_source(
            AwsAccountId=AWS_ACCOUNT_ID,  #AWS account ID
            DataSourceId=data_source_config['DataSourceId'],
            Name=data_source_config['Name'],
            Type=data_source_config['Type'],
            DataSourceParameters=data_source_config['DataSourceParameters']
        )
        
        # Define the physical table configuration
        input_columns = [
            {
                "Name": "country",
                "Type": "STRING"
            },
            {
                "Name": "age",
                "Type": "STRING"
            },
            {
                "Name": "id",
                "Type": "STRING"
            },
            {
                "Name": "salary",
                "Type": "STRING"
            },
            {
                "Name": "city",
                "Type": "STRING"
            },
            {
                "Name": "email",
                "Type": "STRING"
            },
            {
                "Name": "name",
                "Type": "STRING"
            }
        ]
       
        try:
            data_set_name = manifest_key.replace(".manifest", "DSET")
            response_data_set = quicksight.create_data_set(
            AwsAccountId=AWS_ACCOUNT_ID,  #  AWS account ID
            DataSetId=str(uuid.uuid4()),
            Name= data_set_name.upper() ,  #dataset name
            PhysicalTableMap = {
                'S3Source': {
                    "S3Source": {
                            "DataSourceArn": result_datasource['Arn'],  # Data source ARN
                            "UploadSettings": {
                                'Format': 'CSV',
                                'StartFromRow': 1,
                                'ContainsHeader': True,
                                'TextQualifier': 'SINGLE_QUOTE',
                                'Delimiter': ','
                            },
                            "InputColumns": input_columns  # Specify the input columns here
                    },
                },
            },
        ImportMode='SPICE'
        )
            logger.info(f'Dateset is successfully created: Response - {response_data_set} ')
        except Exception as e:
            logger.error(f'Error - {e} ')
            raise e
    
        return response_data_set
    
# Function to send csv data to data set
def send_csv_to_dataset(dataset_id):
    # Start an ingestion
    try:
        ingestion_response = quicksight.create_ingestion(
        DataSetId=dataset_id,
        AwsAccountId=AWS_ACCOUNT_ID,
        IngestionId=str(uuid.uuid4()),
        )
        
        logger.info(f'Ingestion is successfully created: Response - {ingestion_response} ')
        return {
            'statusCode': 200,
            'body': 'CSV sent to QuickSight successfully.'
        }
    except Exception as e:
        logger.error(e)
        return {
            'statusCode': 500,
            'body': f'Error: {str(e)}'
        }

# Function to generate and upload a manifest file to S3
def generate_and_upload_manifest(bucket_name, csv_key, manifest_key):
    logger.info("let's start creating the manifest file")
    # Create an S3 client
    s3_client = boto3.client('s3')
    # Create a sample DataFrame
    manifest_data = {
        "fileLocations": [
            {
                "URIs": [f"s3://{bucket_name}/{csv_key}"]
            }
        ],
        "globalUploadSettings": {
            "format": "CSV",
            "delimiter": ",",
            "textqualifier": "'",
            "containsHeader": "true"
        }
    }
    
    try:
        s3_client.put_object(Bucket=bucket_name,Key=manifest_key,Body=json.dumps(manifest_data), ContentType='application/json')
    except Exception as e:
        logger.error(e)
        return {
            'statusCode': 500,
            'body': f'Error: {str(e)}'
        }
        
# Function to create analysis
def create_analysis(dataset_arn, analysis_name, data_set_placeholder):
    # Define the analysis structure
    analysis_id = str(uuid.uuid4())

    try:
        # Create the analysis
        analysis_response = quicksight.create_analysis(
        AwsAccountId='your-aws-account-id',
        AnalysisId=analysis_id,
        Name=analysis_name,
        SourceEntity={
            'SourceTemplate': {
                'DataSetReferences': [
                    {
                        'DataSetPlaceholder': data_set_placeholder,
                        'DataSetArn': dataset_arn,
                    },
                ],
            },
        },
        )
        logger.info(f'QuickSight analysis created successfully! : Response - {analysis_response} ')
        
        return {
        'statusCode': 200,
        'body': 'QuickSight analysis created successfully!',
        }
        
    except Exception as e:
        logger.error(e)
        return {
            'statusCode': 500,
            'body': f'Error on QuickSight analysis creation : {str(e)}'
        }