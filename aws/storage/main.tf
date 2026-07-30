locals {
  bucket_name = coalesce(var.bucket_name, "${var.project}-${var.name}")

  use_kms        = var.encryption_type == "KMS"
  create_kms_key = local.use_kms && var.kms_key_arn == null
  effective_key  = local.create_kms_key ? module.encryption_kms[0].kms_key_arn : var.kms_key_arn

  replication_enabled = var.replication_role_arn != null && length(var.replication_rules) > 0

  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
    },
    var.tags
  )
}

//---------------------------------------------------------------------
// Dedicated KMS key (only when encryption_type = "KMS" and no key supplied)
//---------------------------------------------------------------------

module "encryption_kms" {
  count = local.create_kms_key ? 1 : 0

  source                      = "../kms"
  alias                       = "alias/s3/${var.project}/${var.environment}/${var.name}"
  description                 = "KMS key for S3 bucket ${local.bucket_name} (${var.environment})"
  kms_rotation_period_in_days = var.kms_rotation_period_in_days
  tags                        = var.tags
}

//---------------------------------------------------------------------
// Bucket
//---------------------------------------------------------------------

resource "aws_s3_bucket" "this" {
  bucket        = local.bucket_name
  force_destroy = var.force_destroy

  tags = merge(
    { Name = local.bucket_name },
    local.common_tags
  )
}

//---------------------------------------------------------------------
// Block all public access (all four flags, always on)
//---------------------------------------------------------------------

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

//---------------------------------------------------------------------
// Ownership controls: disable ACLs entirely (bucket owner owns all objects)
//---------------------------------------------------------------------

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

//---------------------------------------------------------------------
// Server-side encryption (always on)
//---------------------------------------------------------------------

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = local.use_kms ? "aws:kms" : "AES256"
      kms_master_key_id = local.use_kms ? local.effective_key : null
    }
    # Reduce KMS request costs/throttling by using an S3 bucket key.
    bucket_key_enabled = local.use_kms
  }
}

//---------------------------------------------------------------------
// Versioning
//---------------------------------------------------------------------

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

//---------------------------------------------------------------------
// Access logging (optional)
//---------------------------------------------------------------------

resource "aws_s3_bucket_logging" "this" {
  count = var.logging_target_bucket != null ? 1 : 0

  bucket        = aws_s3_bucket.this.id
  target_bucket = var.logging_target_bucket
  target_prefix = coalesce(var.logging_target_prefix, "${local.bucket_name}/")
}
