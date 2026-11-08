# Changelog

All notable changes to this module are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- VPC networking: optional `vpc_config` (`subnet_ids`, `security_group_ids`,
  `ipv6_allowed_for_dual_stack`) emits the function's `vpc_config` block. While
  it is set, the module attaches the AWS managed
  `AWSLambdaVPCAccessExecutionRole` policy to the role in `role_arn` and creates
  the function after the attachment; `attach_vpc_access_policy = false` opts
  out. Without `vpc_config` nothing changes.

### Changed

- Minimum AWS provider raised from 5.0 to 5.23, the first release with
  `vpc_config.ipv6_allowed_for_dual_stack` on `aws_lambda_function`.

## [1.1.0] - 2026-11-05

### Added

- `s3_object_version` pins the deployed object on a versioned bucket.
- `log_group_kms_key_id` encrypts the managed log group with a customer managed
  key.

### Changed

- CI: move actions to their node24 majors, pin tool versions, and group
  Dependabot updates monthly with auto-merge for patches.

## [1.0.0]

Initial release (`v0.1.0` points at the same commit).

[Unreleased]: https://github.com/moveeeax/terraform-aws-lambda/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/moveeeax/terraform-aws-lambda/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/moveeeax/terraform-aws-lambda/releases/tag/v1.0.0
