resource "aws_iam_role" "codebuild" {
  name = "${var.codebuild.name}-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole"
        ]
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
  tags = merge({ Name = "${var.codebuild.name}-role" }, var.tags)
}

data "aws_iam_policy_document" "codebuild" {
  statement {
    sid    = "AllowLogging"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "${aws_cloudwatch_log_group.code_build.arn}:*"
    ]
  }
  statement {
    sid    = "AllowKMSEncryptForLogs"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:GenerateDataKey"
    ]
    resources = [
      module.kms_cb_log_group.kms_key_arn
    ]
  }
  statement {
    sid    = "AWSLambdaLayerPublish"
    effect = "Allow"
    actions = [
      "lambda:PublishLayerVersion"
    ]
    resources = [
      "arn:aws:lambda:${var.aws.region}:${var.aws.account_id}:layer:*"
    ]
  }
  statement {
    sid    = "AllowS3BucketAccess"
    effect = "Allow"
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket"
    ]
    resources = [
      var.artifact_bucket.arn
    ]
  }
  statement {
    sid    = "AllowS3ArtifactAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:PutObjectTagging"
    ]
    resources = [
      "${var.artifact_bucket.arn}/${var.artifact_bucket.layer_prefix}*"
    ]
  }
  statement {
    sid    = "AllowBucketKMS"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = [
      var.artifact_bucket.kms_key_arn
    ]
  }
}

resource "aws_iam_policy" "codebuild" {
  name   = "${var.codebuild.name}-policy"
  policy = data.aws_iam_policy_document.codebuild.json
}

resource "aws_iam_role_policy_attachment" "codebuild" {
  role       = aws_iam_role.codebuild.name
  policy_arn = aws_iam_policy.codebuild.arn
}

resource "aws_codebuild_project" "layer" {
  for_each     = var.layers
  name         = "${each.value.layer_name}-cb"
  service_role = aws_iam_role.codebuild.arn
  artifacts {
    type      = "S3"
    location  = var.artifact_bucket.name
    path      = "${var.artifact_bucket.layer_prefix}lambda_layers/${each.value.layer_name}-cb/"
    name      = "${each.value.layer_name}.zip"
    packaging = "ZIP"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = var.codebuild.image
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "LAYER_NAME"
      value = each.value.layer_name
    }
  }

  source {
    type      = "NO_SOURCE"
    buildspec = file(each.value.buildspec_path)
  }

  logs_config {
    cloudwatch_logs {
      status     = "ENABLED"
      group_name = aws_cloudwatch_log_group.code_build.name
    }
  }
}
