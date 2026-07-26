# terraform-aws-lambda

Terraform module that manages an [AWS Lambda](https://aws.amazon.com/lambda/)
function. It creates a single function from either a local zip or an S3
deployment package, manages the function's CloudWatch log group so retention is
bounded, and exposes the invoke ARN so event sources can be wired to it.

## Usage

```hcl
module "lambda" {
  source = "github.com/moveeeax/terraform-aws-lambda"

  function_name = "api-handler"
  role_arn      = aws_iam_role.lambda.arn
  handler       = "index.handler"
  runtime       = "python3.12"

  filename         = "package.zip"
  source_code_hash = filebase64sha256("package.zip")

  # Environment variables are readable by anyone holding lambda:GetFunction
  # unless they are encrypted with a customer managed key.
  kms_key_arn = aws_kms_key.lambda.arn

  environment_variables = {
    STAGE = "production"
  }

  # Asynchronous invocations that exhaust their retries land here instead of
  # being dropped.
  dead_letter_target_arn = aws_sqs_queue.lambda_dlq.arn

  log_retention_in_days = 30

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

A runnable example lives in [`examples/basic`](examples/basic).

## Notes

- **Always set `source_code_hash`.** Terraform cannot see inside the deployment
  package, so if you rebuild `package.zip` in place without changing its path,
  nothing is redeployed until the hash changes.
- **`reserved_concurrent_executions = 0` disables the function.** The default is
  `-1`, meaning unlimited (drawing on shared account concurrency). `0` is not
  "no reservation" — it throttles the function to zero, and every invocation is
  rejected.
- **The log group is managed by this module.** Lambda would otherwise create
  `/aws/lambda/<function_name>` implicitly, with retention set to never expire
  and outside Terraform's lifecycle. Set `create_log_group = false` if the group
  already exists and is managed elsewhere, otherwise the first apply fails with
  `ResourceAlreadyExistsException` — or import it first.
- **`runtime` has no default** on purpose, so this module cannot silently pin
  you to a runtime that AWS has since deprecated. Check the
  [runtime support policy](https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html)
  when choosing a value.
- **Set `s3_object_version` on a versioned bucket.** Without it, Terraform
  always deploys whatever object currently sits at `s3_key`. If something else
  overwrites that key — another pipeline, a manual upload — the function's
  code changes without Terraform ever planning a diff.

## Testing

The module ships a [`terraform test`](tests/) suite that runs offline against a
mocked provider — no AWS credentials or network access required:

```sh
terraform init -backend=false
terraform test
```

The suite requires Terraform >= 1.7 for `mock_provider`. That is a test-only
requirement; the module itself still supports >= 1.5.

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| aws       | >= 5.0   |

## Inputs

Exactly one of `filename` or `s3_bucket` must be set; `s3_key` is required
whenever `s3_bucket` is. Both rules are enforced at plan time.

| Name                             | Description                                                                              | Type          | Default | Required |
|----------------------------------|------------------------------------------------------------------------------------------|---------------|---------|:--------:|
| `function_name`                  | Name of the Lambda function.                                                             | `string`      | n/a     |   yes    |
| `role_arn`                       | ARN of the execution IAM role.                                                           | `string`      | n/a     |   yes    |
| `handler`                        | Function entrypoint in your code.                                                        | `string`      | n/a     |   yes    |
| `runtime`                        | Runtime the function runs on.                                                            | `string`      | n/a     |   yes    |
| `filename`                       | Path to a local deployment package (zip).                                                | `string`      | `null`  |    no    |
| `s3_bucket`                      | S3 bucket containing the deployment package.                                             | `string`      | `null`  |    no    |
| `s3_key`                         | S3 key of the deployment package.                                                        | `string`      | `null`  |    no    |
| `s3_object_version`              | Version of the S3 object, when `s3_bucket` is set. Pins the deploy on a versioned bucket. | `string`      | `null`  |    no    |
| `source_code_hash`               | Base64 SHA256 of the package; required for in-place zip rebuilds to be redeployed.       | `string`      | `null`  |    no    |
| `publish`                        | Publish an immutable version on every code change.                                       | `bool`        | `false` |    no    |
| `memory_size`                    | Amount of memory in megabytes.                                                           | `number`      | `128`   |    no    |
| `timeout`                        | Execution timeout in seconds.                                                            | `number`      | `3`     |    no    |
| `reserved_concurrent_executions` | Reserved concurrency. `-1` is unlimited; **`0` disables the function**.                   | `number`      | `-1`    |    no    |
| `kms_key_arn`                    | CMK used to encrypt environment variables at rest.                                       | `string`      | `null`  |    no    |
| `dead_letter_target_arn`         | SQS queue or SNS topic for events that failed all async invocation attempts.              | `string`      | `null`  |    no    |
| `create_log_group`               | Manage the function's CloudWatch log group.                                              | `bool`        | `true`  |    no    |
| `log_group_kms_key_id`           | CMK used to encrypt the managed log group at rest.                                       | `string`      | `null`  |    no    |
| `log_retention_in_days`          | Retention for the managed log group. `0` means never expire.                             | `number`      | `14`    |    no    |
| `environment_variables`          | Map of environment variables.                                                            | `map(string)` | `{}`    |    no    |
| `tags`                           | Tags applied to the function and log group.                                              | `map(string)` | `{}`    |    no    |

## Outputs

| Name             | Description                                                          |
|------------------|----------------------------------------------------------------------|
| `id`             | Name of the Lambda function.                                         |
| `arn`            | ARN of the Lambda function.                                          |
| `invoke_arn`     | ARN used to invoke the function.                                     |
| `version`        | Latest published version. `$LATEST` unless `publish` is true.        |
| `qualified_arn`  | ARN including the version. `:$LATEST` unless `publish` is true.      |
| `log_group_name` | Name of the function's CloudWatch log group.                         |
| `log_group_arn`  | ARN of the managed log group, or `null` when `create_log_group` is false. |

## License

[MIT](LICENSE)
