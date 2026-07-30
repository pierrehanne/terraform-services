// Amazon Bedrock Knowledge Bases backed by Amazon S3 Vectors. For each entry in
// var.knowledge_bases the module creates a CMK-encrypted S3 vector bucket and
// index, a least-privilege service role (unless one is supplied), the knowledge
// base itself, and its S3 data sources. Ingestion is left to a pipeline.

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
    },
    var.tags
  )

  # Flatten knowledge_bases -> data_sources into a single map keyed by
  # "<kb>/<ds>" so data sources can be created with for_each.
  data_sources = merge([
    for kb_key, kb in var.knowledge_bases : {
      for ds_key, ds in kb.data_sources :
      "${kb_key}/${ds_key}" => merge(ds, { kb_key = kb_key, ds_key = ds_key })
    }
  ]...)
}

//---------------------------------------------------------------------
// S3 Vectors store (one bucket + index per knowledge base)
//---------------------------------------------------------------------

resource "aws_s3vectors_vector_bucket" "this" {
  for_each = var.knowledge_bases

  vector_bucket_name = "${local.name_prefix}-${each.key}"
  force_destroy      = var.vector_bucket_force_destroy

  encryption_configuration {
    sse_type    = "aws:kms"
    kms_key_arn = var.kms_key_arn
  }

  tags = local.common_tags
}

resource "aws_s3vectors_index" "this" {
  for_each = var.knowledge_bases

  vector_bucket_name = aws_s3vectors_vector_bucket.this[each.key].vector_bucket_name
  index_name         = "${local.name_prefix}-${each.key}"
  data_type          = each.value.data_type
  dimension          = each.value.dimension
  distance_metric    = each.value.distance_metric

  encryption_configuration {
    sse_type    = "aws:kms"
    kms_key_arn = var.kms_key_arn
  }

  dynamic "metadata_configuration" {
    for_each = length(each.value.non_filterable_metadata_keys) > 0 ? [1] : []
    content {
      non_filterable_metadata_keys = each.value.non_filterable_metadata_keys
    }
  }

  tags = local.common_tags
}

//---------------------------------------------------------------------
// Knowledge base
//---------------------------------------------------------------------

resource "aws_bedrockagent_knowledge_base" "this" {
  for_each = var.knowledge_bases

  name        = "${local.name_prefix}-${each.key}"
  description = each.value.description
  role_arn    = each.value.service_role_arn != null ? each.value.service_role_arn : aws_iam_role.kb[each.key].arn

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = var.embedding_model_arn
    }
  }

  storage_configuration {
    type = "S3_VECTORS"
    s3_vectors_configuration {
      vector_bucket_arn = aws_s3vectors_vector_bucket.this[each.key].vector_bucket_arn
      index_arn         = aws_s3vectors_index.this[each.key].index_arn
    }
  }

  tags = local.common_tags
}

//---------------------------------------------------------------------
// Data sources (S3)
//---------------------------------------------------------------------

resource "aws_bedrockagent_data_source" "this" {
  for_each = local.data_sources

  name              = each.value.ds_key
  knowledge_base_id = aws_bedrockagent_knowledge_base.this[each.value.kb_key].id
  # Deleting a data source can purge its vectors; guard that behind the policy.
  data_deletion_policy = each.value.data_deletion_policy

  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn              = each.value.bucket_arn
      bucket_owner_account_id = each.value.bucket_owner_account_id
      inclusion_prefixes      = length(each.value.inclusion_prefixes) > 0 ? each.value.inclusion_prefixes : null
    }
  }

  dynamic "vector_ingestion_configuration" {
    for_each = each.value.chunking.strategy != "NONE" ? [each.value.chunking] : []
    content {
      chunking_configuration {
        chunking_strategy = vector_ingestion_configuration.value.strategy

        dynamic "fixed_size_chunking_configuration" {
          for_each = vector_ingestion_configuration.value.strategy == "FIXED_SIZE" ? [1] : []
          content {
            max_tokens         = vector_ingestion_configuration.value.max_tokens
            overlap_percentage = vector_ingestion_configuration.value.overlap_percentage
          }
        }
      }
    }
  }
}
