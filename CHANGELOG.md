# Changelog

All notable changes to this module are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.2.0] - 2026-11-08

### Added

- VPC networking: optional `vpc_config` (`subnet_ids`, `security_group_ids`,
  `ipv6_allowed_for_dual_stack`) emits the function's `vpc_config` block. While
  it is set, the module attaches the AWS managed
  `AWSLambdaVPCAccessExecutionRole` policy to the role in `role_arn` and creates
  the function after the attachment; `attach_vpc_access_policy = false` opts
  out. Without `vpc_config` nothing changes.
- Container images and arm64: optional `package_type` (`Zip` by default, or
  `Image`), `image_uri`, `image_config` (`command`, `entry_point`,
  `working_directory`) and `architectures` (`["x86_64"]` or `["arm64"]`, null
  by default so Lambda keeps using x86_64). Plan-time preconditions require
  exactly one of `filename`, `s3_bucket` or `image_uri`, tie `image_uri` and
  `image_config` to `Image`, and require `handler` and `runtime` for `Zip` only.

### Changed

- `handler` and `runtime` are no longer required inputs (default `null`), since
  image functions take them from the image. A Zip package still fails at plan
  time without them.
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

[Unreleased]: https://github.com/moveeeax/terraform-aws-lambda/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/moveeeax/terraform-aws-lambda/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/moveeeax/terraform-aws-lambda/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/moveeeax/terraform-aws-lambda/releases/tag/v1.0.0
