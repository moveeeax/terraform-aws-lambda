variable "function_name" {
  description = "Name of the Lambda function."
  type        = string
}

variable "role_arn" {
  description = "ARN of the IAM role the function assumes when it executes."
  type        = string
}

variable "handler" {
  description = "Function entrypoint in your code, for example index.handler."
  type        = string
}

variable "runtime" {
  description = "Runtime the function runs on, for example python3.12 or nodejs20.x."
  type        = string
}

variable "filename" {
  description = "Path to a local deployment package (zip). Mutually exclusive with s3_bucket."
  type        = string
  default     = null
}

variable "s3_bucket" {
  description = "S3 bucket containing the deployment package. Mutually exclusive with filename."
  type        = string
  default     = null
}

variable "s3_key" {
  description = "S3 key of the deployment package when s3_bucket is set."
  type        = string
  default     = null
}

variable "s3_object_version" {
  description = "Version of the S3 object containing the deployment package, when s3_bucket is set. Without this, Terraform always deploys whatever object currently lives at s3_key, so on a versioned bucket another process overwriting that key changes what gets deployed without Terraform ever seeing a diff to plan. Only valid alongside s3_bucket."
  type        = string
  default     = null
}

variable "memory_size" {
  description = "Amount of memory in megabytes the function has access to."
  type        = number
  default     = 128
}

variable "timeout" {
  description = "Function execution timeout in seconds."
  type        = number
  default     = 3
}

variable "source_code_hash" {
  description = <<-EOT
    Base64-encoded SHA256 of the deployment package, used to detect that the
    code changed. Without it Terraform only redeploys when the filename or S3
    key changes, so rebuilding a zip in place is silently ignored. Typically
    `filebase64sha256("package.zip")` or the `output_base64sha256` of an
    `archive_file` data source.
  EOT
  type        = string
  default     = null
}

variable "publish" {
  description = "Whether to publish a new immutable version on every code change. Required for the version and qualified_arn outputs to be anything other than $LATEST."
  type        = bool
  default     = false
}

variable "reserved_concurrent_executions" {
  description = "Concurrent executions reserved for this function. `-1` (the default) means unlimited, drawing on shared account concurrency. Note that `0` is not 'no reservation' — it throttles the function to zero and disables it entirely."
  type        = number
  default     = -1

  validation {
    condition     = var.reserved_concurrent_executions >= -1
    error_message = "reserved_concurrent_executions must be -1 (unlimited) or a non-negative number."
  }
}

variable "kms_key_arn" {
  description = "ARN of a customer managed KMS key used to encrypt environment variables at rest. When null, Lambda uses an AWS managed key that any principal with lambda:GetFunction can read through, so set this whenever environment variables carry secrets."
  type        = string
  default     = null
}

variable "dead_letter_target_arn" {
  description = "ARN of an SQS queue or SNS topic that receives events which failed all asynchronous invocation attempts. When null no dead-letter target is configured and those events are discarded."
  type        = string
  default     = null
}

variable "create_log_group" {
  description = "Whether to manage the function's CloudWatch log group. When false, Lambda creates /aws/lambda/<function_name> implicitly with unbounded retention and Terraform never destroys it."
  type        = bool
  default     = true
}

variable "log_group_kms_key_id" {
  description = "ARN of a customer managed KMS key used to encrypt the function's log group at rest. Only used when create_log_group is true. When null, CloudWatch Logs uses its own encryption with no customer managed key."
  type        = string
  default     = null
}

variable "log_retention_in_days" {
  description = "Retention for the managed CloudWatch log group. Only used when create_log_group is true. `0` means never expire."
  type        = number
  default     = 14

  validation {
    condition = contains(
      [0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653],
      var.log_retention_in_days
    )
    error_message = "log_retention_in_days must be one of the retention periods CloudWatch Logs accepts, or 0 for never expire."
  }
}

variable "environment_variables" {
  description = "Map of environment variables exposed to the function."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags applied to the function."
  type        = map(string)
  default     = {}
}
