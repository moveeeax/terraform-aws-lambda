# Requires Terraform >= 1.7 for mock_provider. This is a test-only requirement;
# the module itself still supports >= 1.5, so versions.tf is deliberately left
# alone. Runs offline against a mocked provider — no credentials needed.

mock_provider "aws" {}

variables {
  function_name = "unit-test-fn"
  role_arn      = "arn:aws:iam::111111111111:role/unit-test"
  handler       = "index.handler"
  runtime       = "python3.12"
  filename      = "package.zip"
}

run "defaults_are_safe" {
  command = plan

  assert {
    condition     = aws_lambda_function.this.reserved_concurrent_executions == -1
    error_message = "Default concurrency must be -1 (unlimited); 0 would throttle the function to zero and disable it."
  }

  assert {
    condition     = length(aws_cloudwatch_log_group.this) == 1
    error_message = "The log group must be managed by default so retention is bounded."
  }

  assert {
    condition     = aws_cloudwatch_log_group.this[0].name == "/aws/lambda/unit-test-fn"
    error_message = "Managed log group must use the name Lambda would otherwise create implicitly."
  }

  assert {
    condition     = aws_cloudwatch_log_group.this[0].retention_in_days == 14
    error_message = "Logs must expire by default rather than being retained forever."
  }

  assert {
    condition     = output.log_group_name == "/aws/lambda/unit-test-fn"
    error_message = "log_group_name output must match the actual log group."
  }
}

run "optional_blocks_are_absent_by_default" {
  command = plan

  assert {
    condition     = length(aws_lambda_function.this.dead_letter_config) == 0
    error_message = "No dead-letter target should be configured unless one is supplied."
  }

  assert {
    condition     = length(aws_lambda_function.this.environment) == 0
    error_message = "No environment block should be emitted for an empty variable map."
  }

  assert {
    condition     = aws_lambda_function.this.kms_key_arn == null
    error_message = "kms_key_arn must be unset unless the caller supplies a key."
  }

  assert {
    condition     = aws_lambda_function.this.publish == false
    error_message = "Publishing versions must stay opt-in."
  }
}

run "encryption_and_dlq_are_wired_through" {
  command = plan

  variables {
    kms_key_arn            = "arn:aws:kms:us-east-1:111111111111:key/00000000-0000-0000-0000-000000000000"
    dead_letter_target_arn = "arn:aws:sqs:us-east-1:111111111111:unit-test-dlq"
    source_code_hash       = "hFV2p3wLZ0wLh4v8H2xJ8sJ2mQ4kQZ0e5xWjJhFqQ1c="
    environment_variables  = { STAGE = "test" }
  }

  assert {
    condition     = aws_lambda_function.this.kms_key_arn == "arn:aws:kms:us-east-1:111111111111:key/00000000-0000-0000-0000-000000000000"
    error_message = "kms_key_arn must reach the function so environment variables are encrypted with the caller's CMK."
  }

  assert {
    condition     = one(aws_lambda_function.this.dead_letter_config).target_arn == "arn:aws:sqs:us-east-1:111111111111:unit-test-dlq"
    error_message = "dead_letter_target_arn must produce a dead_letter_config block."
  }

  assert {
    condition     = aws_lambda_function.this.source_code_hash == "hFV2p3wLZ0wLh4v8H2xJ8sJ2mQ4kQZ0e5xWjJhFqQ1c="
    error_message = "source_code_hash must reach the function so in-place zip rebuilds are redeployed."
  }

  assert {
    condition     = one(aws_lambda_function.this.environment).variables["STAGE"] == "test"
    error_message = "environment_variables must reach the function."
  }
}

run "log_group_can_be_disabled" {
  command = plan

  variables {
    create_log_group = false
  }

  assert {
    condition     = length(aws_cloudwatch_log_group.this) == 0
    error_message = "create_log_group = false must not create a log group."
  }

  assert {
    condition     = output.log_group_arn == null
    error_message = "log_group_arn must be null when the log group is not managed."
  }
}

run "rejects_negative_concurrency_below_unlimited" {
  command = plan

  variables {
    reserved_concurrent_executions = -2
  }

  expect_failures = [var.reserved_concurrent_executions]
}

run "rejects_invalid_log_retention" {
  command = plan

  variables {
    log_retention_in_days = 12
  }

  expect_failures = [var.log_retention_in_days]
}

run "rejects_missing_deployment_package" {
  command = plan

  variables {
    filename = null
  }

  expect_failures = [aws_lambda_function.this]
}

run "rejects_both_deployment_package_sources" {
  command = plan

  variables {
    s3_bucket = "unit-test-artifacts"
    s3_key    = "fn.zip"
  }

  expect_failures = [aws_lambda_function.this]
}

run "rejects_s3_bucket_without_key" {
  command = plan

  variables {
    filename  = null
    s3_bucket = "unit-test-artifacts"
  }

  expect_failures = [aws_lambda_function.this]
}
