// Runtime execution role, created only when runtime.execution_role_arn is not
// supplied. Trust is scoped to the AgentCore service with source-account /
// source-arn conditions; permissions are least-privilege: ECR image pull (for
// container artifacts), CloudWatch Logs, KMS decrypt for the supplied key, plus
// any caller-supplied statements.

data "aws_iam_policy_document" "execution_assume" {
  count = local.create_execution_role ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["bedrock-agentcore.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:bedrock-agentcore:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*"]
    }
  }
}

data "aws_iam_policy_document" "execution" {
  count = local.create_execution_role ? 1 : 0

  # ECR authorization token is not resource-scopable.
  dynamic "statement" {
    for_each = var.runtime.container_uri != null ? [1] : []
    content {
      sid       = "EcrAuth"
      effect    = "Allow"
      actions   = ["ecr:GetAuthorizationToken"]
      resources = ["*"]
    }
  }

  # Image pull scoped to the specific repository.
  dynamic "statement" {
    for_each = var.runtime.container_uri != null && var.ecr_repository_arn != null ? [1] : []
    content {
      sid    = "EcrPull"
      effect = "Allow"
      actions = [
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer",
      ]
      resources = [var.ecr_repository_arn]
    }
  }

  # Code artifact read from S3.
  dynamic "statement" {
    for_each = var.runtime.code != null ? [1] : []
    content {
      sid       = "CodeArtifactRead"
      effect    = "Allow"
      actions   = ["s3:GetObject"]
      resources = ["arn:aws:s3:::${var.runtime.code.s3_bucket}/${var.runtime.code.s3_prefix}*"]
    }
  }

  statement {
    sid    = "Logs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/bedrock-agentcore/*"]
  }

  dynamic "statement" {
    for_each = var.kms_key_arn != null ? [1] : []
    content {
      sid    = "Kms"
      effect = "Allow"
      actions = [
        "kms:Decrypt",
        "kms:GenerateDataKey",
        "kms:DescribeKey",
      ]
      resources = [var.kms_key_arn]
    }
  }

  dynamic "statement" {
    for_each = var.additional_execution_policy_statements
    content {
      sid       = statement.value.sid
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

resource "aws_iam_role" "execution" {
  count = local.create_execution_role ? 1 : 0

  name               = "${local.name_prefix}-runtime-role"
  assume_role_policy = data.aws_iam_policy_document.execution_assume[0].json

  tags = merge(
    { Name = "${local.name_prefix}-runtime-role" },
    local.common_tags
  )
}

resource "aws_iam_role_policy" "execution" {
  count = local.create_execution_role ? 1 : 0

  name   = "${local.name_prefix}-runtime-policy"
  role   = aws_iam_role.execution[0].id
  policy = data.aws_iam_policy_document.execution[0].json
}
