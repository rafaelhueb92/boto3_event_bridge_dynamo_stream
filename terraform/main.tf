provider "aws" {
  region = "us-west-2"  # Change to your preferred AWS region
}

# IAM Role for Lambda functions
resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
      }
    ]
  })
}

# IAM Policies for Lambda role
resource "aws_iam_role_policy" "lambda_policy" {
  name   = "lambda_policy"
  role   = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["dynamodb:GetItem"],
        Effect   = "Allow",
        Resource = aws_dynamodb_table.identification_table.arn
      },
      {
        Action   = [
          "events:PutRule",
          "events:PutTargets",
          "lambda:InvokeFunction",
          "events:DeleteRule",
          "events:RemoveTargets"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

# DynamoDB table for storing data
resource "aws_dynamodb_table" "identification_table" {
  name           = "identification_table"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "identification"

  attribute {
    name = "identification"
    type = "S"
  }
}

# Create a zip file for each Lambda function
data "archive_file" "trigger_lambda_zip" {
  type        = "zip"
  source_file = "path/to/trigger_lambda.py"
  output_path = "${path.module}/trigger_lambda.zip"
}

data "archive_file" "process_lambda_zip" {
  type        = "zip"
  source_file = "path/to/process_lambda.py"
  output_path = "${path.module}/process_lambda.zip"
}

# Lambda function to create EventBridge rules
resource "aws_lambda_function" "trigger_lambda" {
  function_name = "trigger_lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "trigger_lambda.lambda_handler"
  runtime       = "python3.9"
  filename      = data.archive_file.trigger_lambda_zip.output_path

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.identification_table.name
    }
  }
}

# Lambda function to process data from DynamoDB
resource "aws_lambda_function" "process_lambda" {
  function_name = "process_lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "process_lambda.lambda_handler"
  runtime       = "python3.9"
  filename      = data.archive_file.process_lambda_zip.output_path

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.identification_table.name
    }
  }
}

# EventBridge rule (created dynamically by trigger_lambda, this is a placeholder)
resource "aws_cloudwatch_event_rule" "placeholder_rule" {
  name        = "placeholder_rule"
  description = "Placeholder rule created dynamically by trigger_lambda"
  is_enabled  = false
}

# EventBridge target to trigger process_lambda
resource "aws_cloudwatch_event_target" "process_lambda_target" {
  rule      = aws_cloudwatch_event_rule.placeholder_rule.name
  target_id = "process_lambda"
  arn       = aws_lambda_function.process_lambda.arn
}

# Permissions for EventBridge to invoke process_lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.placeholder_rule.arn
}
