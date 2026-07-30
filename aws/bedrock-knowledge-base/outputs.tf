output "knowledge_bases" {
  description = "Map of knowledge base key to its created identifiers and vector store ARNs."
  value = {
    for k, kb in aws_bedrockagent_knowledge_base.this : k => {
      id                = kb.id
      arn               = kb.arn
      name              = kb.name
      vector_bucket_arn = aws_s3vectors_vector_bucket.this[k].vector_bucket_arn
      index_arn         = aws_s3vectors_index.this[k].index_arn
      service_role_arn  = kb.role_arn
    }
  }
}

output "data_source_ids" {
  description = "Map of \"<kb>/<data-source>\" to its data source ID. Feed these (with the KB id) into `aws bedrock-agent start-ingestion-job` from a pipeline to sync content."
  value       = { for k, ds in aws_bedrockagent_data_source.this : k => ds.data_source_id }
}

output "service_role_arns" {
  description = "Map of knowledge base key to the module-created service role ARN (only for KBs that did not supply their own service_role_arn)."
  value       = { for k, r in aws_iam_role.kb : k => r.arn }
}
