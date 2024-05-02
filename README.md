# AWS Data Pipeline with Lambda and QuickSight

## Description
This project implements a data pipeline on AWS, using Lambda functions and Terraform to automate the infrastructure. The pipeline starts with JSON files being uploaded to an S3 bucket. A Lambda function is triggered to process the JSON file, extract key-value pairs, and convert the data into a CSV file. The CSV file is then uploaded to AWS QuickSight for visualization.

Once the visualization is ready, an SNS notification is triggered to indicate that the report has been generated. This project also includes Python scripts for processing data and Terraform configurations to set up AWS resources like Lambda functions and S3 buckets.

## Project Structure
- `lambda/`: Contains Lambda function scripts and a QuickSight module.
  - `lambda_fonction.py`: The main Lambda function script for processing JSON files and creating CSV files.
  - `quicksight_module.py`: A module for interacting with AWS QuickSight.
- `requirements.txt`: Lists the Python dependencies required by the Lambda function.

## Prerequisites
- AWS account with appropriate permissions.
- Terraform installed on your local machine.
- Python 3.x and pip installed.
- AWS CLI configured with your account credentials.

## Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/your-username/your-repo.git
   cd your-repo

2. Initialize Terraform:
   ```bash
   terraform init
   
3. Apply Terraform configuration::
   ```bash
   terraform apply -auto-approve
4. Install Python dependencies:
   ```bash
   pip install -r requirements.txt
 
## Usage
- To use the pipeline, follow these steps:
   ```bash
**1. Upload a JSON file to the designated S3 bucket**.
**2. Lambda function processing**:
Once the JSON file is uploaded, the Lambda function will process the file, convert it into a CSV, and upload it to AWS QuickSight.
**3. SNS notification**:
After the QuickSight visualization is ready, an SNS notification is triggered to indicate that the report has been generated.

## Contributing
Contributions are welcome! If you'd like to contribute, please create a pull request or open an issue for discussion.

## Licence
This project is licensed under the MIT License.




