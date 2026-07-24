//---------------------------------------------------------------------
// Security Groups
//---------------------------------------------------------------------

output "bedrock_security_group_id" {
  description = "ID of the security group attached to Bedrock interface endpoints."
  value       = try(aws_security_group.bedrock[0].id, null)
}

output "transcribe_security_group_id" {
  description = "ID of the security group attached to the Transcribe interface endpoint."
  value       = try(aws_security_group.transcribe[0].id, null)
}

//---------------------------------------------------------------------
// Bedrock Interface Endpoints
//---------------------------------------------------------------------

output "bedrock_endpoint_ids" {
  description = "Map of Bedrock service name to VPC endpoint ID."
  value       = { for k, v in aws_vpc_endpoint.interface : k => v.id }
}

output "bedrock_endpoint_dns_entries" {
  description = "Map of Bedrock service name to list of DNS entries for the endpoint."
  value       = { for k, v in aws_vpc_endpoint.interface : k => v.dns_entry }
}

output "bedrock_endpoint_network_interface_ids" {
  description = "Map of Bedrock service name to the endpoint's network interface IDs."
  value       = { for k, v in aws_vpc_endpoint.interface : k => v.network_interface_ids }
}

//---------------------------------------------------------------------
// Cloudwatch Interface Endpoint
//---------------------------------------------------------------------

output "cloudwatch_security_group_id" {
  description = "ID of the security group attached to CloudWatch interface endpoints."
  value       = try(aws_security_group.cloudwatch[0].id, null)
}

output "cloudwatch_endpoint_ids" {
  description = "Map of CloudWatch service name (logs, monitoring) to VPC endpoint ID."
  value       = { for k, v in aws_vpc_endpoint.cloudwatch : k => v.id }
}

output "cloudwatch_endpoint_dns_entries" {
  description = "Map of CloudWatch service name to DNS entries for the endpoint."
  value       = { for k, v in aws_vpc_endpoint.cloudwatch : k => v.dns_entry }
}

//---------------------------------------------------------------------
// ECR Interface Endpoint
//---------------------------------------------------------------------

output "ecr_security_group_id" {
  description = "ID of the security group attached to ECR interface endpoints."
  value       = try(aws_security_group.ecr[0].id, null)
}

output "ecr_endpoint_ids" {
  description = "Map of ECR service name (ecr.api, ecr.dkr) to VPC endpoint ID."
  value       = { for k, v in aws_vpc_endpoint.ecr : k => v.id }
}

output "ecr_endpoint_dns_entries" {
  description = "Map of ECR service name to DNS entries for the endpoint."
  value       = { for k, v in aws_vpc_endpoint.ecr : k => v.dns_entry }
}

//---------------------------------------------------------------------
// DynamoDB Gateway Endpoint
//---------------------------------------------------------------------

output "dynamodb_endpoint_id" {
  description = "ID of the DynamoDB gateway endpoint."
  value       = try(aws_vpc_endpoint.dynamodb[0].id, null)
}

output "dynamodb_endpoint_project_list_id" {
  description = "project list ID of the DynamoDB gateway endpoint (useful for route table / SG rules)."
  value       = try(aws_vpc_endpoint.dynamodb[0].project_list_id, null)
}

//---------------------------------------------------------------------
// Transcribe Interface Endpoint
//---------------------------------------------------------------------

output "transcribe_endpoint_id" {
  description = "ID of the Transcribe interface endpoint."
  value       = try(aws_vpc_endpoint.transcribe[0].id, null)
}

output "transcribe_endpoint_dns_entries" {
  description = "DNS entries for the Transcribe interface endpoint."
  value       = try(aws_vpc_endpoint.transcribe[0].dns_entry, null)
}

//---------------------------------------------------------------------
// S3 Gateway Endpoint
//---------------------------------------------------------------------

output "s3_endpoint_id" {
  description = "ID of the S3 gateway endpoint."
  value       = try(aws_vpc_endpoint.s3[0].id, null)
}

output "s3_endpoint_project_list_id" {
  description = "project list ID of the S3 gateway endpoint (useful for route table / SG rules)."
  value       = try(aws_vpc_endpoint.s3[0].project_list_id, null)
}
