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
<!-- terraform-docs will populate inputs/outputs here on pre-commit -->
<!-- END_TF_DOCS -->
