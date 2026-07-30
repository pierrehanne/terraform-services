// Per-knowledge-base service role, created only for KBs that don't supply their
// own service_role_arn. Least-privilege: scoped to the embedding model, the
// specific source buckets + prefixes, the created vector bucket/index, and the
// KMS key. The trust policy carries source-account/source-arn conditions to
// prevent the confused-deputy problem.

locals {
  # KBs that need a module-managed role.
  managed_role_kbs = {
    for k, kb in var.knowledge_bases : k => kb
    if kb.service_role_arn == null
  }

  kb_arn_prefix = "arn:aws:bedrock:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:knowledge-base"

  # Distinct source bucket ARNs per KB (for the S3 read statements).
  kb_source_bucket_arns = {
    for k, kb in var.knowledge_bases :
    k => distinct([for dk, ds in kb.data_sources : ds.bucket_arn])
  }
}

data "aws_iam_policy_document" "assume" {
  for_each = local.managed_role_kbs

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["${local.kb_arn_prefix}/*"]
    }
  }
}

data "aws_iam_policy_document" "kb" {
  for_each = local.managed_role_kbs

  statement {
    sid       = "InvokeEmbeddingModel"
    effect    = "Allow"
    actions   = ["bedrock:InvokeModel"]
    resources = [var.embedding_model_arn]
  }

  # Read the source content.
  dynamic "statement" {
    for_each = length(local.kb_source_bucket_arns[each.key]) > 0 ? [1] : []
    content {
      sid       = "ListSourceBuckets"
      effect    = "Allow"
      actions   = ["s3:ListBucket"]
      resources = local.kb_source_bucket_arns[each.key]
    }
  }

  dynamic "statement" {
    for_each = length(local.kb_source_bucket_arns[each.key]) > 0 ? [1] : []
    content {
      sid       = "GetSourceObjects"
      effect    = "Allow"
      actions   = ["s3:GetObject"]
      resources = [for arn in local.kb_source_bucket_arns[each.key] : "${arn}/*"]
    }
  }

  # S3 Vectors data plane, scoped to this KB's bucket + index.
  statement {
    sid     = "S3VectorsAccess"
    effect  = "Allow"
    actions = var.s3vectors_iam_actions
    resources = [
      aws_s3vectors_vector_bucket.this[each.key].vector_bucket_arn,
      aws_s3vectors_index.this[each.key].index_arn,
    ]
  }

  # Decrypt/encrypt for the CMK protecting the source, vector store and transient
  # ingestion data.
  statement {
    sid    = "KmsAccess"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey",
    ]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role" "kb" {
  for_each = local.managed_role_kbs

  name               = "${local.name_prefix}-${each.key}-kb-role"
  assume_role_policy = data.aws_iam_policy_document.assume[each.key].json

  tags = merge(
    { Name = "${local.name_prefix}-${each.key}-kb-role" },
    local.common_tags
  )
}

resource "aws_iam_role_policy" "kb" {
  for_each = local.managed_role_kbs

  name   = "${local.name_prefix}-${each.key}-kb-policy"
  role   = aws_iam_role.kb[each.key].id
  policy = data.aws_iam_policy_document.kb[each.key].json
}
