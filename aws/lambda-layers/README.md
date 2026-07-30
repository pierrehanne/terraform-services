# Lambda Layers

Builds Lambda layer artifacts with AWS CodeBuild and publishes them as
`aws_lambda_layer_version` resources. Point the module at a map of layer
definitions and an existing artifact bucket, and each layer is compiled in an
isolated CodeBuild project (`NO_SOURCE`, driven by an inline buildspec) and its
`.zip` published as a new layer version.

## Design principles

- **CodeBuild-driven builds.** Each entry in `layers` gets its own
  `aws_codebuild_project` that runs the layer's buildspec and writes the
  resulting artifact to the shared S3 bucket. There is no local build step.
- **Publishes layer versions.** For every built artifact the module creates an
  `aws_lambda_layer_version`, wiring `source_code_hash` to the artifact's ETag so
  a new version is published whenever the build output changes.
- **Scoped CodeBuild IAM role.** A single execution role and inline policy grant
  only what the build needs: CloudWatch Logs, `lambda:PublishLayerVersion`,
  scoped S3 access to the artifact prefix, and the two KMS keys (log group and
  bucket).
- **KMS-encrypted CloudWatch logs.** The CodeBuild log group is encrypted with a
  customer-managed key created via the shared [`kms`](../kms) module, using a key
  policy scoped to the log group ARN.
- **Map-driven, multi-layer.** All per-layer resources use `for_each` over the
  `layers` map, so one module instance can build and publish any number of
  layers.
- **Externally-provided artifact bucket.** The module does not create the S3
  bucket; it consumes an existing one via the `artifact_bucket` object (name,
  ARN, KMS key, and layer prefix).

## Usage

```hcl
module "lambda_layers" {
  source = "../lambda-layers"

  project     = "acme"
  environment = "production"

  aws = {
    account_id = "123456789012"
    region     = "eu-west-1"
  }

  artifact_bucket = {
    name         = "acme-build-artifacts"
    arn          = "arn:aws:s3:::acme-build-artifacts"
    kms_key_arn  = "arn:aws:kms:eu-west-1:123456789012:key/00000000-0000-0000-0000-000000000000"
    layer_prefix = "artifacts/"
  }

  codebuild = {
    name          = "acme-lambda-layers"
    image         = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    timeout       = 600
    log_retention = 30
  }

  layers = {
    common = {
      layer_name     = "acme-common"
      buildspec_path = "${path.module}/buildspecs/common.yml"
      runtimes       = ["python3.12"]
      architectures  = ["x86_64"]
    }
  }

  tags = { ManagedBy = "terraform" }
}
```

- [`examples/simple`](./examples/simple) — one layer built and published from an
  existing artifact bucket.

## Notes

- Builds are orchestrated by a `null_resource.build_layer` (one per layer) whose
  `triggers` hash the buildspec, so a changed buildspec re-runs the build. Its
  `local-exec` provisioner invokes [`utils/check_codebuild.sh`](./utils/check_codebuild.sh),
  which starts the CodeBuild build and polls until it succeeds, fails, or the
  configured `codebuild.timeout` elapses.
- `artifact_bucket` must reference a real, pre-existing S3 bucket; this module
  reads from and writes to it but never creates it.
- `aws_lambda_layer_version` does not accept a `tags` argument — layer versions
  cannot be tagged via the AWS API — so it is the one resource here left
  untagged.

<!-- BEGIN_TF_DOCS -->
<!-- terraform-docs will populate inputs/outputs here on pre-commit -->
<!-- END_TF_DOCS -->
