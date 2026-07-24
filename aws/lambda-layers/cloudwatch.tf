locals {
  cloudwatch_log_group_name = replace(
    var.codebuild.name,
    "-",
    "/"
  )
}

data "aws_iam_policy_document" "kms_cb_log_group" {
  statement {
    sid    = "EnableIAMUserPermissions"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${var.aws.account_id}:root"
      ]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }
  statement {
    sid    = "AllowDeliveryLogs"
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = [
        "logs.${var.aws.region}.amazonaws.com"
      ]
    }
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    resources = ["*"]
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values = [
        "arn:aws:logs:${var.aws.region}:${var.aws.account_id}:log-group:${local.cloudwatch_log_group_name}",
        "arn:aws:logs:${var.aws.region}:${var.aws.account_id}:log-group:${local.cloudwatch_log_group_name}:*"
      ]
    }
  }
}

module "kms_cb_log_group" {
  source      = "../kms"
  alias       = "alias/cloudwatch/${var.project}/${var.environment}/${var.codebuild.name}"
  description = "CloudWatch encryption key for ${var.codebuild.name} (${var.environment})"
  kms_policy  = data.aws_iam_policy_document.kms_cb_log_group.json
  tags        = var.tags
}

resource "aws_cloudwatch_log_group" "code_build" {
  name              = local.cloudwatch_log_group_name
  retention_in_days = var.codebuild.log_retention
  kms_key_id        = module.kms_cb_log_group.kms_key_arn
  tags              = var.tags
}
