locals {
  name_prefix = "${var.project}-${var.name}"

  has_inline_policy = length(var.inline_policy_statements) > 0

  common_tags = merge({ Project = var.project, Environment = var.environment }, var.tags)
}

//---------------------------------------------------------------------
// Trust relationship
//---------------------------------------------------------------------

data "aws_iam_policy_document" "assume_role" {
  statement {
    sid     = "AssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    dynamic "principals" {
      for_each = length(var.trusted_services) > 0 ? [1] : []
      content {
        type        = "Service"
        identifiers = var.trusted_services
      }
    }

    dynamic "principals" {
      for_each = length(var.trusted_role_arns) > 0 ? [1] : []
      content {
        type        = "AWS"
        identifiers = var.trusted_role_arns
      }
    }

    dynamic "condition" {
      for_each = var.trust_conditions
      content {
        test     = condition.value.test
        variable = condition.value.variable
        values   = condition.value.values
      }
    }
  }
}

resource "aws_iam_role" "this" {
  name                 = local.name_prefix
  description          = "Role for ${var.name} (${var.environment})"
  assume_role_policy   = data.aws_iam_policy_document.assume_role.json
  max_session_duration = var.max_session_duration
  permissions_boundary = var.permissions_boundary_arn

  # A trust policy with no principal is rejected by IAM at apply time; fail
  # early with a clear message instead.
  lifecycle {
    precondition {
      condition     = length(var.trusted_services) + length(var.trusted_role_arns) > 0
      error_message = "At least one of trusted_services or trusted_role_arns must be set."
    }
  }

  tags = merge(
    { Name = local.name_prefix },
    local.common_tags
  )
}

//---------------------------------------------------------------------
// Managed policy attachments (AWS-managed or customer-managed)
//---------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = toset(var.managed_policy_arns)

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

//---------------------------------------------------------------------
// Structured inline policy -> customer-managed policy + attachment
//---------------------------------------------------------------------

data "aws_iam_policy_document" "inline" {
  count = local.has_inline_policy ? 1 : 0

  dynamic "statement" {
    for_each = var.inline_policy_statements
    content {
      sid       = statement.value.sid
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources

      dynamic "condition" {
        for_each = statement.value.conditions
        content {
          test     = condition.value.test
          variable = condition.value.variable
          values   = condition.value.values
        }
      }
    }
  }
}

resource "aws_iam_policy" "inline" {
  count = local.has_inline_policy ? 1 : 0

  name        = "${local.name_prefix}-policy"
  description = "Least-privilege policy for ${var.name} (${var.environment})"
  policy      = data.aws_iam_policy_document.inline[0].json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "inline" {
  count = local.has_inline_policy ? 1 : 0

  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.inline[0].arn
}

//---------------------------------------------------------------------
// Raw JSON policy escape hatch
//---------------------------------------------------------------------

resource "aws_iam_policy" "custom" {
  count = var.policy_json != null ? 1 : 0

  name        = "${local.name_prefix}-custom"
  description = "Custom policy (raw JSON) for ${var.name} (${var.environment})"
  policy      = var.policy_json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "custom" {
  count = var.policy_json != null ? 1 : 0

  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.custom[0].arn
}
