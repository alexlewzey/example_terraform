terraform {
  # Assumes s3 bucket and dynamo db table already exist, if they do not exist comment out
  backend "s3" {
    bucket         = "lewzey-tf-state"
    key            = "tf-infra/terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "terraform-state-locking"
    encrypt        = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.4.2"
}


provider "aws" {
  region = "eu-west-2"
}


variable "bucket_name" {
  type        = string
  default     = "lewzey-ml-bucket"
  description = "Bucket name"
}


locals {
  bucket_name = var.bucket_name
}

# tfsec:ignore:AWS002 tfsec:ignore:AWS017 tfsec:ignore:AWS077
resource "aws_s3_bucket" "my_bucket" {
  bucket        = local.bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.my_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


resource "aws_iam_policy" "lambda_s3_put_policy" {
  name        = "lambda_s3_put_policy"
  description = "IAM policy for Lambda to put objects in S3"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = ["s3:PutObject"],
        Effect   = "Allow",
        Resource = "${aws_s3_bucket.my_bucket.arn}/*"
      }
    ],
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "my_bucket_lifecycle" {
  bucket = aws_s3_bucket.my_bucket.id
  rule {
    status = "Enabled"
    id     = "expire_all_files"
    expiration {
      days = 1
    }
  }
}


resource "aws_lambda_function" "my_lambda" {
  function_name    = "my_lambda_function"
  runtime          = "python3.10"
  filename         = "lambda/python_lambda.zip"
  source_code_hash = filebase64sha256("lambda/python_lambda.zip")
  handler          = "index.handler"
  role             = aws_iam_role.lambda_exec.arn
  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.my_bucket.bucket
    }
  }
}


resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
      },
    ],
  })
}


resource "aws_iam_role_policy_attachment" "lambda_s3_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_s3_put_policy.arn
}


resource "aws_cloudwatch_event_rule" "every_minute" {
  name                = "every-minute"
  description         = "Trigger every minute"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "trigger_lambda" {
  rule      = aws_cloudwatch_event_rule.every_minute.name
  target_id = "MyLambda"
  arn       = aws_lambda_function.my_lambda.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_lambda" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.my_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_minute.arn
}


output "my_bucket_arn" {
  value       = aws_s3_bucket.my_bucket.arn
  sensitive   = true
  description = "My bucket arn"
  depends_on  = [aws_s3_bucket.my_bucket]
}


resource "aws_secretsmanager_secret" "terraform_outputs" {
  name                    = "terraform_outputs"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "terraform_outputs_current" {
  secret_id = aws_secretsmanager_secret.terraform_outputs.id
  secret_string = jsonencode({
    "my_bucket_arn" = aws_s3_bucket.my_bucket.arn,
    "my_lambda_arn" = aws_lambda_function.my_lambda.arn
  })
}



data "aws_secretsmanager_secret" "secret_greeting" {
  name = "greeting"
}

data "aws_secretsmanager_secret_version" "secret_greeting_current" {
  secret_id = data.aws_secretsmanager_secret.secret_greeting.id
}

output "secret_greeting_value" {
  value      = data.aws_secretsmanager_secret_version.secret_greeting_current.secret_string
  sensitive  = true
  depends_on = [data.aws_secretsmanager_secret_version.secret_greeting_current]
}
