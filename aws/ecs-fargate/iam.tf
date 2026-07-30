data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

//---------------------------------------------------------------------
// Execution role (per service): pull images, write logs, read secrets.
//---------------------------------------------------------------------

resource "aws_iam_role" "execution" {
  for_each = var.services

  name               = "${local.name_prefix}-${each.key}-exec"
  assume_role_policy = data.aws_iam_policy_document.assume.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  for_each = var.services

  role       = aws_iam_role.execution[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Grant the execution role read access to exactly the secrets this service
# consumes (and decrypt on the keys protecting them) — nothing broader.
data "aws_iam_policy_document" "execution_secrets" {
  for_each = { for k, s in var.services : k => s if length(s.secrets) > 0 }

  statement {
    sid       = "ReadSecrets"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue", "ssm:GetParameters"]
    resources = values(each.value.secrets)
  }

  dynamic "statement" {
    for_each = length(each.value.secret_kms_key_arns) > 0 ? [1] : []
    content {
      sid       = "DecryptSecrets"
      effect    = "Allow"
      actions   = ["kms:Decrypt"]
      resources = each.value.secret_kms_key_arns
    }
  }
}

resource "aws_iam_role_policy" "execution_secrets" {
  for_each = data.aws_iam_policy_document.execution_secrets

  name   = "read-secrets"
  role   = aws_iam_role.execution[each.key].id
  policy = each.value.json
}

//---------------------------------------------------------------------
// Task role (per service): the application's own permissions.
//---------------------------------------------------------------------

resource "aws_iam_role" "task" {
  for_each = var.services

  name               = "${local.name_prefix}-${each.key}-task"
  assume_role_policy = data.aws_iam_policy_document.assume.json

  tags = local.common_tags
}

data "aws_iam_policy_document" "task" {
  for_each = { for k, s in var.services : k => s if length(s.task_policy_statements) > 0 }

  dynamic "statement" {
    for_each = each.value.task_policy_statements
    content {
      sid       = statement.value.sid
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

resource "aws_iam_role_policy" "task" {
  for_each = data.aws_iam_policy_document.task

  name   = "app-permissions"
  role   = aws_iam_role.task[each.key].id
  policy = each.value.json
}
