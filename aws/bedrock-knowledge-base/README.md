# Bedrock Knowledge Base (S3 Vectors)

Provisions one or more Amazon Bedrock Knowledge Bases backed by **Amazon S3
Vectors** as the vector store. For each entry in `knowledge_bases` the module
creates a CMK-encrypted S3 vector bucket and index, a least-privilege IAM
service role (unless you supply one), the knowledge base, and its S3 data
sources — all from a single module instance.

## Design principles

- **S3 Vectors only.** The vector store is always `S3_VECTORS` — a serverless,
  cost-effective option with no OpenSearch/RDS cluster to run. Other store types
  are intentionally out of scope.
- **N knowledge bases per instance.** `knowledge_bases` is a map keyed by name,
  matching the repo's `guardrails`/`services` convention.
- **Encryption by default.** Vector buckets and indexes are encrypted with the
  supplied customer-managed KMS key (`aws:kms`).
- **Least-privilege service role.** The module creates one role per KB, scoped
  to the embedding model ARN, the exact source buckets/prefixes, the created
  vector bucket + index, and the KMS key — with source-account/source-arn trust
  conditions to prevent the confused-deputy problem. Bring your own role with
  `service_role_arn`.
- **Ingestion stays out-of-band.** Terraform creates the data sources but does
  **not** trigger a sync — that would make plans non-idempotent. Use the
  exported ids from a pipeline instead (see below).

## Usage

```hcl
module "kb" {
  source = "../bedrock-knowledge-base"

  project     = "acme"
  environment = "production"

  kms_key_arn         = module.kms.kms_key_arn
  embedding_model_arn = "arn:aws:bedrock:eu-west-1::foundation-model/amazon.titan-embed-text-v2:0"

  knowledge_bases = {
    docs = {
      dimension = 1024
      data_sources = {
        manuals = {
          bucket_arn         = "arn:aws:s3:::acme-kb-source"
          inclusion_prefixes = ["manuals/"]
        }
      }
    }
  }

  tags = { ManagedBy = "terraform" }
}
```

- [`examples/simple`](./examples/simple) — one KB over one S3 data source.

## Triggering ingestion

After apply, sync each data source from a pipeline or runbook:

```sh
aws bedrock-agent start-ingestion-job \
  --knowledge-base-id "$KB_ID" \
  --data-source-id "$DATA_SOURCE_ID"
```

`KB_ID` comes from `knowledge_bases[<key>].id` and `DATA_SOURCE_ID` from
`data_source_ids["<kb>/<data-source>"]`.

## Notes

- **Dimension must match the model.** `dimension` has to equal the embedding
  model's output dimension (Titan Text Embeddings V2 supports 256 / 512 / 1024).
  A mismatch fails at ingestion, not at apply.
- **Chunking:** `FIXED_SIZE` (with `max_tokens` / `overlap_percentage`) or `NONE`
  (one chunk per file). Semantic/hierarchical chunking are out of scope here.
- **`data_deletion_policy`** defaults to `RETAIN` so removing a data source does
  not purge its vectors; set `DELETE` to have them cleaned up.
- **S3 Vectors IAM surface is new.** The exact `s3vectors:*` action names the
  service role needs may change; override `s3vectors_iam_actions` without editing
  the module if AWS adjusts them.
- **Source bucket** must be readable with the supplied KMS key (SSE-KMS on the
  source is granted decrypt via the same key ARN).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.15 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.57 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.57 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_bedrockagent_data_source.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bedrockagent_data_source) | resource |
| [aws_bedrockagent_knowledge_base.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bedrockagent_knowledge_base) | resource |
| [aws_iam_role.kb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.kb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_s3vectors_index.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3vectors_index) | resource |
| [aws_s3vectors_vector_bucket.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3vectors_vector_bucket) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.kb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_embedding_model_arn"></a> [embedding\_model\_arn](#input\_embedding\_model\_arn) | ARN of the Bedrock embedding model used to vectorize content, e.g. arn:aws:bedrock:<region>::foundation-model/amazon.titan-embed-text-v2:0. Its output dimension must match each knowledge base's index dimension. | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (e.g., production, staging, development) | `string` | n/a | yes |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | ARN of the KMS key used to encrypt the S3 vector buckets and indexes at rest (from the kms module). Also granted to the KB service role for decrypt. | `string` | n/a | yes |
| <a name="input_knowledge_bases"></a> [knowledge\_bases](#input\_knowledge\_bases) | Map of Bedrock knowledge bases to create, keyed by name. | <pre>map(object({<br/>    description = optional(string)<br/><br/>    # Vector index geometry. dimension MUST equal the embedding model's output<br/>    # dimension (e.g. Titan v2 supports 256/512/1024); distance_metric is<br/>    # typically "cosine" for text embeddings.<br/>    dimension       = number<br/>    distance_metric = optional(string, "cosine")<br/>    data_type       = optional(string, "float32")<br/><br/>    # Metadata keys excluded from filtering (stored but not indexed for filters).<br/>    non_filterable_metadata_keys = optional(list(string), [])<br/><br/>    # Reuse an existing service role instead of letting the module create one.<br/>    service_role_arn = optional(string)<br/><br/>    # S3 data sources attached to this KB, keyed by data source name.<br/>    data_sources = optional(map(object({<br/>      bucket_arn              = string<br/>      bucket_owner_account_id = optional(string)<br/>      inclusion_prefixes      = optional(list(string), [])<br/>      data_deletion_policy    = optional(string, "RETAIN")<br/><br/>      # Chunking. strategy: FIXED_SIZE (with max_tokens/overlap) or NONE (one<br/>      # chunk per file). SEMANTIC/HIERARCHICAL are out of scope for this version.<br/>      chunking = optional(object({<br/>        strategy           = optional(string, "FIXED_SIZE")<br/>        max_tokens         = optional(number, 300)<br/>        overlap_percentage = optional(number, 20)<br/>      }), {})<br/>    })), {})<br/>  }))</pre> | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | Project name used for naming and organizing resources | `string` | n/a | yes |
| <a name="input_s3vectors_iam_actions"></a> [s3vectors\_iam\_actions](#input\_s3vectors\_iam\_actions) | S3 Vectors data-plane actions granted to the KB service role, scoped to the created vector bucket and index. Exposed as a variable because the s3vectors:* IAM surface is new and may change — override without editing the module. | `list(string)` | <pre>[<br/>  "s3vectors:GetIndex",<br/>  "s3vectors:QueryVectors",<br/>  "s3vectors:GetVectors",<br/>  "s3vectors:PutVectors",<br/>  "s3vectors:ListVectors",<br/>  "s3vectors:DeleteVectors"<br/>]</pre> | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags applied to all resources created by this module | `map(string)` | `{}` | no |
| <a name="input_vector_bucket_force_destroy"></a> [vector\_bucket\_force\_destroy](#input\_vector\_bucket\_force\_destroy) | Whether S3 vector buckets can be destroyed while still containing vectors. Keep false in production. | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_data_source_ids"></a> [data\_source\_ids](#output\_data\_source\_ids) | Map of "<kb>/<data-source>" to its data source ID. Feed these (with the KB id) into `aws bedrock-agent start-ingestion-job` from a pipeline to sync content. |
| <a name="output_knowledge_bases"></a> [knowledge\_bases](#output\_knowledge\_bases) | Map of knowledge base key to its created identifiers and vector store ARNs. |
| <a name="output_service_role_arns"></a> [service\_role\_arns](#output\_service\_role\_arns) | Map of knowledge base key to the module-created service role ARN (only for KBs that did not supply their own service\_role\_arn). |
<!-- END_TF_DOCS -->
