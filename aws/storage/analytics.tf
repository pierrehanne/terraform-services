//---------------------------------------------------------------------
// Glue Catalog database + crawler and Athena workgroup (all optional).
// These are only created when explicitly requested, keeping plain storage
// buckets free of analytics resources.
//---------------------------------------------------------------------

locals {
  glue_database_name = coalesce(
    var.glue_database_name,
    replace("${var.project}_${var.name}", "-", "_")
  )
  glue_crawler_target = coalesce(var.glue_crawler_s3_path, "s3://${local.bucket_name}/")
}

resource "aws_glue_catalog_database" "this" {
  count = var.enable_glue_database ? 1 : 0

  name        = local.glue_database_name
  description = "Glue database for ${local.bucket_name} (${var.environment})"

  tags = local.common_tags
}

resource "aws_glue_crawler" "this" {
  count = var.enable_glue_crawler ? 1 : 0

  name          = "${var.project}-${var.name}-crawler"
  role          = var.glue_crawler_role_arn
  database_name = aws_glue_catalog_database.this[0].name
  schedule      = var.glue_crawler_schedule

  s3_target {
    path = local.glue_crawler_target
  }

  tags = local.common_tags
}

resource "aws_athena_workgroup" "this" {
  count = var.enable_athena_workgroup ? 1 : 0

  name = "${var.project}-${var.name}"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.this.id}/${var.athena_results_prefix}"

      encryption_configuration {
        encryption_option = local.use_kms ? "SSE_KMS" : "SSE_S3"
        kms_key_arn       = local.use_kms ? local.effective_key : null
      }
    }
  }

  tags = local.common_tags
}
