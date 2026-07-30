locals {
  repository_name = "${var.project}/${var.name}"

  use_kms        = var.encryption_type == "KMS"
  create_kms_key = local.use_kms && var.kms_key_arn == null
  effective_key  = local.create_kms_key ? module.encryption_kms[0].kms_key_arn : var.kms_key_arn

  common_tags = merge({ Project = var.project, Environment = var.environment }, var.tags)
}

//---------------------------------------------------------------------
// Dedicated KMS key (only when encryption_type = "KMS" and no key supplied)
//---------------------------------------------------------------------

module "encryption_kms" {
  count = local.create_kms_key ? 1 : 0

  source                      = "../kms"
  alias                       = "alias/ecr/${var.project}/${var.environment}/${var.name}"
  description                 = "KMS key for ECR repository ${local.repository_name} (${var.environment})"
  kms_rotation_period_in_days = var.kms_rotation_period_in_days
  tags                        = local.common_tags
}

//---------------------------------------------------------------------
// Repository
//---------------------------------------------------------------------

resource "aws_ecr_repository" "this" {
  name                 = local.repository_name
  image_tag_mutability = var.image_tag_mutability
  force_delete         = var.force_delete

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = local.use_kms ? "KMS" : "AES256"
    kms_key         = local.use_kms ? local.effective_key : null
  }

  tags = merge(
    { Name = local.repository_name },
    local.common_tags
  )
}

//---------------------------------------------------------------------
// Lifecycle policy
//---------------------------------------------------------------------

locals {
  # Rule ordering matters: ECR applies rules by ascending priority and an image
  # matched by one rule is excluded from later ones. Expire untagged first, then
  # cap the number of tagged images.
  #
  # Note: ECR lifecycle rules cannot express "all tags except these", so there
  # is no reliable way to exempt specific tag prefixes from the count rule. If
  # you need to guarantee certain images are never expired, pin them by digest
  # in your deployments or provide a fully custom lifecycle_policy_json.
  default_lifecycle_rules = [
    {
      rulePriority = 1
      description  = "Expire untagged images"
      selection = {
        tagStatus   = "untagged"
        countType   = "sinceImagePushed"
        countUnit   = "days"
        countNumber = var.untagged_image_expiry_days
      }
      action = { type = "expire" }
    },
    {
      rulePriority = 10
      description  = "Keep only the most recent tagged images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.max_tagged_image_count
      }
      action = { type = "expire" }
    },
  ]

  lifecycle_policy = var.lifecycle_policy_json != null ? var.lifecycle_policy_json : jsonencode({
    rules = local.default_lifecycle_rules
  })
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name
  policy     = local.lifecycle_policy
}

//---------------------------------------------------------------------
// Repository (resource) policy
//
// The module does not generate a repository policy. Same-account access is
// granted through IAM identity policies on the consumers (ECS task roles, CI
// roles, etc.). Supply repository_policy_json only for advanced cases that
// genuinely require a resource-based policy.
//---------------------------------------------------------------------

resource "aws_ecr_repository_policy" "this" {
  count = var.repository_policy_json != null ? 1 : 0

  repository = aws_ecr_repository.this.name
  policy     = var.repository_policy_json
}
