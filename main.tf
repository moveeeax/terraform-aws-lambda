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
  kms_key_id        = var.log_group_kms_key_id
  tags              = var.tags
}

# A function attached to a VPC reaches it through ENIs that Lambda creates with
# the execution role, so the role needs ec2:CreateNetworkInterface and friends.
# The role is owned by the caller; only the AWS managed policy is attached here,
# and only while vpc_config is set. The role name and partition are taken from
# role_arn so roles with a path and non-commercial partitions work.
resource "aws_iam_role_policy_attachment" "vpc_access" {
  count = var.vpc_config != null && var.attach_vpc_access_policy ? 1 : 0

  role       = element(split("/", var.role_arn), length(split("/", var.role_arn)) - 1)
  policy_arn = "arn:${split(":", var.role_arn)[1]}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  role          = var.role_arn
  handler       = var.handler
  runtime       = var.runtime
  architectures = var.architectures

  # package_type forces replacement, so it defaults to Zip, the value the
  # provider and Lambda already assume for functions created before it existed.
  package_type = var.package_type
  image_uri    = var.image_uri

  filename          = var.filename
  s3_bucket         = var.s3_bucket
  s3_key            = var.s3_key
  s3_object_version = var.s3_object_version
  source_code_hash  = var.source_code_hash

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

  dynamic "image_config" {
    for_each = var.image_config == null ? [] : [var.image_config]
    content {
      command           = image_config.value.command
      entry_point       = image_config.value.entry_point
      working_directory = image_config.value.working_directory
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config == null ? [] : [var.vpc_config]
    content {
      subnet_ids                  = vpc_config.value.subnet_ids
      security_group_ids          = vpc_config.value.security_group_ids
      ipv6_allowed_for_dual_stack = vpc_config.value.ipv6_allowed_for_dual_stack
    }
  }

  tags = var.tags

  # Create the managed log group first so the function cannot beat Terraform to
  # it and leave an unmanaged, never-expiring group behind. The VPC policy
  # attachment must also exist first: CreateFunction rejects a VPC config when
  # the role cannot create network interfaces yet.
  depends_on = [
    aws_cloudwatch_log_group.this,
    aws_iam_role_policy_attachment.vpc_access,
  ]

  lifecycle {
    precondition {
      condition     = length([for source in [var.filename, var.s3_bucket, var.image_uri] : source if source != null]) == 1
      error_message = "Exactly one of filename, s3_bucket or image_uri must be set."
    }

    precondition {
      condition     = (var.package_type == "Image") == (var.image_uri != null)
      error_message = "image_uri is required when package_type is Image and only valid then; use filename or s3_bucket for a Zip package."
    }

    precondition {
      condition     = var.package_type != "Zip" || (var.handler != null && var.runtime != null)
      error_message = "handler and runtime must be set when package_type is Zip."
    }

    precondition {
      condition     = var.package_type != "Image" || (var.handler == null && var.runtime == null)
      error_message = "handler and runtime come from the container image when package_type is Image; leave them null and use image_config to override the entrypoint."
    }

    precondition {
      condition     = var.image_config == null || var.package_type == "Image"
      error_message = "image_config only applies when package_type is Image."
    }

    precondition {
      condition     = var.s3_bucket == null || var.s3_key != null
      error_message = "s3_key must be set when the deployment package comes from s3_bucket."
    }

    precondition {
      condition     = var.s3_object_version == null || var.s3_bucket != null
      error_message = "s3_object_version only applies to a package sourced from s3_bucket."
    }
  }
}
