data "archive_file" "lambda" {
  type        = "zip"
  source_file = "register.py"
  output_path = "lambda_function_payload.zip"
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