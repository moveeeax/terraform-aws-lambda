output "id" {
  description = "Name of the Lambda function."
  value       = aws_lambda_function.this.id
}

output "arn" {
  description = "ARN of the Lambda function."
  value       = aws_lambda_function.this.arn
}

output "invoke_arn" {
  description = "ARN used to invoke the function from API Gateway or other services."
  value       = aws_lambda_function.this.invoke_arn
}

output "version" {
  description = "Latest published version of the function. Stays $LATEST unless publish is true."
  value       = aws_lambda_function.this.version
}

output "qualified_arn" {
  description = "ARN of the function including the version. Resolves to :$LATEST unless publish is true."
  value       = aws_lambda_function.this.qualified_arn
}

output "log_group_name" {
  description = "Name of the function's CloudWatch log group, whether or not this module manages it."
  value       = local.log_group_name
}

output "log_group_arn" {
  description = "ARN of the managed CloudWatch log group, or null when create_log_group is false."
  value       = one(aws_cloudwatch_log_group.this[*].arn)
}
