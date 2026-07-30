variable "project" {
  description = "Project name used for naming and organizing resources"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., production, staging, development)"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt the S3 vector buckets and indexes at rest (from the kms module). Also granted to the KB service role for decrypt."
  type        = string
}

variable "embedding_model_arn" {
  description = "ARN of the Bedrock embedding model used to vectorize content, e.g. arn:aws:bedrock:<region>::foundation-model/amazon.titan-embed-text-v2:0. Its output dimension must match each knowledge base's index dimension."
  type        = string
}

//---------------------------------------------------------------------
// Knowledge bases
//
// A map of knowledge base name => definition. One module instance creates N
// independent knowledge bases, each with its own S3 vector store, IAM service
// role and S3 data sources. Ingestion (sync) is intentionally NOT triggered by
// this module — call bedrock-agent start-ingestion-job from a pipeline using
// the exported knowledge_base_id / data_source_ids.
//---------------------------------------------------------------------

variable "knowledge_bases" {
  description = "Map of Bedrock knowledge bases to create, keyed by name."
  type = map(object({
    description = optional(string)

    # Vector index geometry. dimension MUST equal the embedding model's output
    # dimension (e.g. Titan v2 supports 256/512/1024); distance_metric is
    # typically "cosine" for text embeddings.
    dimension       = number
    distance_metric = optional(string, "cosine")
    data_type       = optional(string, "float32")

    # Metadata keys excluded from filtering (stored but not indexed for filters).
    non_filterable_metadata_keys = optional(list(string), [])

    # Reuse an existing service role instead of letting the module create one.
    service_role_arn = optional(string)

    # S3 data sources attached to this KB, keyed by data source name.
    data_sources = optional(map(object({
      bucket_arn              = string
      bucket_owner_account_id = optional(string)
      inclusion_prefixes      = optional(list(string), [])
      data_deletion_policy    = optional(string, "RETAIN")

      # Chunking. strategy: FIXED_SIZE (with max_tokens/overlap) or NONE (one
      # chunk per file). SEMANTIC/HIERARCHICAL are out of scope for this version.
      chunking = optional(object({
        strategy           = optional(string, "FIXED_SIZE")
        max_tokens         = optional(number, 300)
        overlap_percentage = optional(number, 20)
      }), {})
    })), {})
  }))

  validation {
    condition     = alltrue([for k, kb in var.knowledge_bases : contains(["cosine", "euclidean"], kb.distance_metric)])
    error_message = "Each knowledge base distance_metric must be \"cosine\" or \"euclidean\"."
  }

  validation {
    condition     = alltrue([for k, kb in var.knowledge_bases : kb.dimension > 0 && kb.dimension <= 4096])
    error_message = "Each knowledge base dimension must be between 1 and 4096 and match the embedding model's output dimension."
  }

  validation {
    condition = alltrue(flatten([
      for k, kb in var.knowledge_bases : [
        for dk, ds in kb.data_sources : contains(["RETAIN", "DELETE"], ds.data_deletion_policy)
      ]
    ]))
    error_message = "Each data source data_deletion_policy must be \"RETAIN\" or \"DELETE\"."
  }

  validation {
    condition = alltrue(flatten([
      for k, kb in var.knowledge_bases : [
        for dk, ds in kb.data_sources : contains(["FIXED_SIZE", "NONE"], ds.chunking.strategy)
      ]
    ]))
    error_message = "Each data source chunking.strategy must be FIXED_SIZE or NONE (SEMANTIC/HIERARCHICAL are out of scope for this version)."
  }
}

variable "vector_bucket_force_destroy" {
  description = "Whether S3 vector buckets can be destroyed while still containing vectors. Keep false in production."
  type        = bool
  default     = false
}

variable "s3vectors_iam_actions" {
  description = "S3 Vectors data-plane actions granted to the KB service role, scoped to the created vector bucket and index. Exposed as a variable because the s3vectors:* IAM surface is new and may change — override without editing the module."
  type        = list(string)
  default = [
    "s3vectors:GetIndex",
    "s3vectors:QueryVectors",
    "s3vectors:GetVectors",
    "s3vectors:PutVectors",
    "s3vectors:ListVectors",
    "s3vectors:DeleteVectors",
  ]
}

variable "tags" {
  description = "Common tags applied to all resources created by this module"
  type        = map(string)
  default     = {}
}
