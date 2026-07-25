locals {
  log_group_name = "/aws/lambda/${var.function_name}"
}

# Lambda creates this log group implicitly on first invocation with a "never
# expire" retention policy, outside of Terraform's control. Creating it here
# keeps retention bounded and makes the group part of the module's lifecycle.
resource "aws_cloudwatch_log_group" "this" {
  count = var.create_log_group ? 1 : 0

  name              = local.log_group_name
  retention_in_days = var.log_retention_in_days
  tags              = var.tags
}

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  role          = var.role_arn
  handler       = var.handler
  runtime       = var.runtime

  filename         = var.filename
  s3_bucket        = var.s3_bucket
  s3_key           = var.s3_key
  source_code_hash = var.source_code_hash

  memory_size = var.memory_size
  timeout     = var.timeout
  publish     = var.publish

  # -1 means "unlimited" (the function draws on shared account concurrency).
  # 0 is a valid value that throttles the function to zero, i.e. disables it.
  reserved_concurrent_executions = var.reserved_concurrent_executions

  # Without a customer managed key Lambda encrypts environment variables with an
  # AWS managed key that every principal holding lambda:GetFunction can
  # transparently decrypt. A CMK lets the key policy gate that access.
  kms_key_arn = var.kms_key_arn

  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [1] : []
    content {
      variables = var.environment_variables
    }
  }

  dynamic "dead_letter_config" {
    for_each = var.dead_letter_target_arn == null ? [] : [1]
    content {
      target_arn = var.dead_letter_target_arn
    }
  }

  tags = var.tags

  # Create the managed log group first so the function cannot beat Terraform to
  # it and leave an unmanaged, never-expiring group behind.
  depends_on = [aws_cloudwatch_log_group.this]

  lifecycle {
    precondition {
      condition     = (var.filename != null) != (var.s3_bucket != null)
      error_message = "Exactly one of filename or s3_bucket must be set."
    }

    precondition {
      condition     = var.s3_bucket == null || var.s3_key != null
      error_message = "s3_key must be set when the deployment package comes from s3_bucket."
    }
  }
}
