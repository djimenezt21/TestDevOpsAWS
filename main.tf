resource "aws_iam_policy" "policy" {
  name        = var.policy_name
  path        = "/"
  description = "policy for dynamodb and logging"


  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode(
  {
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Stmt1428341300017",
      "Action": [
        "dynamodb:DeleteItem",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:UpdateItem"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Sid": "",
      "Resource": "*",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow"
    }
  ]
} 
  )
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.policy.arn
}

# Tabla DynamoDB
resource "aws_dynamodb_table" "registrations" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "name"
    type = "S"
  }
  
  attribute {
    name = "email"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  attribute {
    name = "datetime"
    type = "S"
  }

# Global Secondary Index for name queries
  global_secondary_index {
    name               = "NameIndex"
    hash_key           = "name"
    projection_type    = "INCLUDE"
    non_key_attributes = ["email", "timestamp"]
    write_capacity     = 5
    read_capacity      = 5
  }
  global_secondary_index {
    name               = "EmailIndex"
    hash_key           = "email"
    projection_type    = "ALL"  # Includes all attributes
    write_capacity     = 5      # Only needed if not PAY_PER_REQUEST
    read_capacity      = 5      # Only needed if not PAY_PER_REQUEST
  }

  global_secondary_index {
    name               = "TimestampIndex"
    hash_key           = "datetime"
    range_key          = "timestamp"
    projection_type    = "INCLUDE"
    non_key_attributes = ["name", "email"]
    write_capacity     = 5
    read_capacity      = 5
  }
}

resource "aws_lambda_function" "test_lambda" {
  # If the file is not in the current working directory you will need to include a
  # path.module in the filename.
  filename      = "lambda_function_payload.zip"
  function_name = var.lambda_function_name
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "handler"

  source_code_hash = data.archive_file.lambda.output_base64sha256

  runtime = "python3.10"

    environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.registrations.name
    }
  }
}

# API Gateway
resource "aws_apigatewayv2_api" "api" {
  name          = var.api_name
  protocol_type = "HTTP"
}

# Integración de Lambda con API Gateway
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.api.id
  integration_type = "AWS_PROXY"

  connection_type    = "INTERNET"
  description        = "Lambda integration for /register"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.test_lambda.invoke_arn
}

# Ruta /register en API Gateway
resource "aws_apigatewayv2_route" "register_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /register"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Permiso para que API Gateway invoque Lambda
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.test_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.api.execution_arn}/*/*/register"
}

# Stage de despliegue
resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "prod"
  auto_deploy = true
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = 7  # Reduce costos (default es 30)
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.lambda_function_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"  # 5 minutos
  statistic           = "Sum"
  threshold           = "1"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  alarm_description = "Alerta cuando ocurren errores en la Lambda"
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${var.lambda_function_name}-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  alarm_description = "Alerta cuando la Lambda es throttled"
}
