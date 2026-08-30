data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  common_tags = merge(var.tags, {
    Module = "vertical-scaler"
  })

  function_name = "${var.name_prefix}-vertical-scaler"
}

# Zip the Python source at plan/apply time — no separate build step.
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = var.lambda_source_dir
  output_path = "${path.module}/.build/${local.function_name}.zip"
  excludes    = ["__pycache__", "*.pyc", ".pytest_cache"]
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    Name = "/aws/lambda/${local.function_name}"
  })
}

resource "aws_iam_role" "lambda" {
  name = "${var.name_prefix}-vertical-scaler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "lambda" {
  name = "${var.name_prefix}-vertical-scaler"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Logs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "${aws_cloudwatch_log_group.lambda.arn}:*"
      },
      {
        Sid    = "ReadEcs"
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
        ]
        Resource = "*"
      },
      {
        Sid    = "WriteEcs"
        Effect = "Allow"
        Action = [
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService",
        ]
        # RegisterTaskDefinition does not support resource-level ARNs.
        Resource = "*"
      },
      {
        Sid    = "PassTaskRoles"
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = [
          var.task_execution_role_arn,
          var.task_role_arn,
        ]
      },
    ]
  })
}

resource "aws_lambda_function" "scaler" {
  function_name = local.function_name
  role          = aws_iam_role.lambda.arn
  handler       = "handler.handler"
  runtime       = "python3.12"
  timeout       = 60
  memory_size   = 128

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      CLUSTER_NAME = var.cluster_name
      SERVICE_NAME = var.service_name
      SIZE_LADDER  = jsonencode(var.size_ladder)
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy.lambda,
  ]

  tags = merge(local.common_tags, {
    Name = local.function_name
  })
}

resource "aws_sns_topic_subscription" "alarms" {
  topic_arn = var.sns_topic_arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.scaler.arn
}

resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scaler.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = var.sns_topic_arn
}
