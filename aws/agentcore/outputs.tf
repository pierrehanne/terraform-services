//---------------------------------------------------------------------
// Runtime
//---------------------------------------------------------------------

output "runtime_arn" {
  description = "ARN of the AgentCore runtime"
  value       = aws_bedrockagentcore_agent_runtime.this.agent_runtime_arn
}

output "runtime_id" {
  description = "ID of the AgentCore runtime"
  value       = aws_bedrockagentcore_agent_runtime.this.agent_runtime_id
}

output "runtime_version" {
  description = "Version of the AgentCore runtime"
  value       = aws_bedrockagentcore_agent_runtime.this.agent_runtime_version
}

output "runtime_endpoint_arn" {
  description = "ARN of the runtime endpoint (the invocable interface)"
  value       = aws_bedrockagentcore_agent_runtime_endpoint.this.agent_runtime_endpoint_arn
}

output "workload_identity_arn" {
  description = "ARN of the workload identity the runtime auto-creates (used by the Identity plane)"
  value       = try(aws_bedrockagentcore_agent_runtime.this.workload_identity_details[0].workload_identity_arn, null)
}

output "execution_role_arn" {
  description = "ARN of the runtime execution role (module-created or supplied)"
  value       = local.execution_role_arn
}

//---------------------------------------------------------------------
// Memory
//---------------------------------------------------------------------

output "memory_arn" {
  description = "ARN of the AgentCore Memory (null when memory is not configured)"
  value       = try(aws_bedrockagentcore_memory.this[0].arn, null)
}

output "memory_id" {
  description = "ID of the AgentCore Memory (null when memory is not configured)"
  value       = try(aws_bedrockagentcore_memory.this[0].id, null)
}

//---------------------------------------------------------------------
// Gateway
//---------------------------------------------------------------------

output "gateway_id" {
  description = "ID of the AgentCore Gateway (null when gateway is not configured). Add gateway targets against this."
  value       = try(aws_bedrockagentcore_gateway.this[0].gateway_id, null)
}

output "gateway_arn" {
  description = "ARN of the AgentCore Gateway (null when gateway is not configured)"
  value       = try(aws_bedrockagentcore_gateway.this[0].gateway_arn, null)
}

output "gateway_url" {
  description = "MCP URL of the AgentCore Gateway (null when gateway is not configured)"
  value       = try(aws_bedrockagentcore_gateway.this[0].gateway_url, null)
}

//---------------------------------------------------------------------
// Identity
//---------------------------------------------------------------------

output "identity_workload_arn" {
  description = "ARN of the explicitly-created workload identity (null when not created)"
  value       = try(aws_bedrockagentcore_workload_identity.this[0].workload_identity_arn, null)
}

output "oauth2_credential_provider_arns" {
  description = "Map of OAuth2 credential provider name to ARN"
  value       = { for k, p in aws_bedrockagentcore_oauth2_credential_provider.this : k => p.credential_provider_arn }
}

output "api_key_credential_provider_arns" {
  description = "Map of API-key credential provider name to ARN"
  value       = { for k, p in aws_bedrockagentcore_api_key_credential_provider.this : k => p.credential_provider_arn }
}
