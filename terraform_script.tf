provider "aws" {
  region     = "us-east-1"
  access_key = "" # your access key here
  secret_key = "" # your secret key here
}
data "aws_caller_identity" "current" {}

# AWS S3 Bucket for Data Ingestion
resource "aws_s3_bucket" "data_bucket" {
  bucket = "regisarmel-data-bucket"
}

# AWS S3 Bucket for Report Storage 
resource "aws_s3_bucket" "report_bucket" {
  bucket = "regisarmel-report-bucket"
}

# AWS SNS Topic for Notifications
resource "aws_sns_topic" "report_notification" {
  name = "report_notification_topic"
}
# AWS SNS Topic for Notifications:
resource "aws_sns_topic" "data_ingestion_notification" {
  name = "data_ingestion_notification_topic"
}


data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}
#iam s3_get_and_put_object_policy
resource "aws_iam_policy" "s3_get_and_put_object_policy" {
  name        = "my_s3_get_and_put_object_policy"
  description = "Policy to allow Lambda function to get and put objects from S3"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "s3:GetObject",
        Effect = "Allow",
        Resource =  "arn:aws:s3:::regisarmel-data-bucket/*" 
      },
       {
        Action = "s3:PutObject",
        Effect = "Allow",
        Resource =  "arn:aws:s3:::regisarmel-data-bucket/*" 
      },
       {
        Action = "s3:GetObject",
        Effect = "Allow",
        Resource =  "arn:aws:s3:::regisarmel-report-bucket/*" 
      },
       {
        Action = "s3:PutObject",
        Effect = "Allow",
        Resource =  "arn:aws:s3:::regisarmel-report-bucket/*" 
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "attach_s3_get_and_put_object_policy" {
  policy_arn = aws_iam_policy.s3_get_and_put_object_policy.arn
  roles      = [aws_iam_role.iam_for_lambda.name]
  name       = "attach s3 get object"
}

#iam for lambda
resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_optimization_lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.data_bucket.arn
}

# Attach necessary permissions to the Lambda execution role
resource "aws_iam_policy_attachment" "lambda_execution_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  roles      = [aws_iam_role.iam_for_lambda.name]
  name       = "lambda_exec_name"
}

#AWS Lambda Function for Data Optimization:
resource "aws_lambda_function" "data_optimization_lambda" {
  filename      = "lambda/lambda_function.zip" # optimization script into a ZIP file
  function_name = "data_optimization_function"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.8"
  timeout      = 60  # Set the timeout to 60 seconds
  role          = aws_iam_role.iam_for_lambda.arn
  layers        = ["arn:aws:lambda:us-east-1:336392948345:layer:AWSSDKPandas-Python38:9"]
   environment {
    variables = {
      QUICKSIGHT_DATASET_ID = "59ba6864-336a-43df-b3b3-6fd276f5a841",
      QUICKSIGHT_AWS_REGION = "us-east-1"  # QuickSight region
      AWS_ACCOUNT_ID = data.aws_caller_identity.current.account_id
      QUICKSIGHT_DATASET_ID = "my_quicksight_default_id"
      QUICKSIGHT_DATASET_NAME ="MY DEMO DATASET"
      QUICKSIGHT_DATASOURCE_NAME = "MY DEMO DATASOURCE"
      QUICKSIGHT_DATASOURCE_ID ="MY_DEMO_DATASOURCE_ID_REGIS"
      CSV_BUCKET = aws_s3_bucket.report_bucket.id
    }
  }
}


#AWS S3 Event Trigger:
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.data_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.data_optimization_lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }
    depends_on = [aws_lambda_permission.allow_bucket]

}

#AWS SNS Topic Subscription:
resource "aws_sns_topic_subscription" "lambda_subscription" {
  topic_arn = aws_sns_topic.data_ingestion_notification.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.data_optimization_lambda.arn
}


# Policy for Lambda to interact with QuickSight
resource "aws_iam_policy" "quick_sight_policy" {
  name        = "quick_sight_policy"
  description = "Allows Lambda to interact with QuickSight"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "quicksight:CreateDataSet",
          "quicksight:UpdateDataSet",
          "quicksight:CreateDataSource",
          "quicksight:UpdateDataSource",
          "quicksight:RegisterUser",
          "quicksight:ListDataSets",
        ],
        Effect   = "Allow",
        Resource = "*",
      },
    ],
  })
}

# Attach the QuickSight policy to the Lambda role
resource "aws_iam_role_policy_attachment" "quick_sight_attachment" {
  policy_arn = aws_iam_policy.quick_sight_policy.arn
  role       = aws_iam_role.iam_for_lambda.name
}

resource "aws_iam_policy" "quicksight_policy" {
  name        = "QuickSightPolicy"
  description = "IAM policy for Amazon QuickSight access"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = [
          "quicksight:GetDashboard",
          "quicksight:GetDashboardEmbedUrl",
          "quicksight:GetDashboardEmbedUrlForAnonymousUser",
          "quicksight:GetDashboardEmbedUrlForRegisteredUser",
          "quicksight:GetSessionEmbedUrl",
          "quicksight:GetSessionEmbedUrlForAnonymousUser",
          "quicksight:GetSessionEmbedUrlForRegisteredUser",
          "quicksight:GetSessionEmbedUrlForAnonymousUser",
          "quicksight:GetSessionEmbedUrlForRegisteredUser",
          "quicksight:GenerateEmbedUrlForAnonymousUser",
          "quicksight:GenerateEmbedUrlForRegisteredUser",
          "quicksight:GenerateEmbedUrlForRegisteredUser",
          "quicksight:ListDashboards",
          "quicksight:ListDataSets",
          "quicksight:DescribeDataSet",
          "quicksight:DescribeDataSetPermissions",
          "quicksight:PassDataSet",
          "quicksight:PassDataSource",
          "quicksight:CreateIngestion",
          "quicksight:QueryDataSet",
          "quicksight:CreateDataSet",
          "quicksight:UpdateDataSet",
          "quicksight:DeleteDataSet",
          "quicksight:CreateAnalysis",
          "quicksight:UpdateAnalysis",
          "quicksight:DeleteAnalysis"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ],
  })
}

resource "aws_iam_role_policy_attachment" "lambda_quicksight_policy_attachment" {
  policy_arn = aws_iam_policy.quicksight_policy.arn
  role       = aws_iam_role.iam_for_lambda.name
}



resource "aws_iam_policy" "quicksight_s3_policy" {
  name        = "QuicksightS3Policy"
  description = "Policy for QuickSight to access S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject"
        ],
        Effect   = "Allow"
        Resource = [
          "arn:aws:s3:::regisarmel-report-bucket/*", 
          "arn:aws:s3:::regisarmel-report-bucket"     # Replace with your S3 bucket name
        ],
      },
      {
        Action   = [
          "s3:GetBucketLocation",
        ],
        Effect   = "Allow",
        Resource = "*",
      },
    ],
  })
}



resource "aws_iam_role" "quicksight_role" {
  name = "QuicksightRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "quicksight.amazonaws.com",
        },
      },
    ],
  })
}

resource "aws_iam_policy_attachment" "quicksight_s3_policy_attachment" {
  policy_arn = aws_iam_policy.quicksight_s3_policy.arn
  roles      = [aws_iam_role.quicksight_role.name]
  name = "quick_sight_att"
}
