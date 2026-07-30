output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC (useful for security group rules)"
  value       = aws_vpc.this.cidr_block
}

output "vpc_arn" {
  description = "ARN of the VPC"
  value       = aws_vpc.this.arn
}

output "availability_zones" {
  description = "Availability Zones the subnets are spread across"
  value       = local.azs
}

//---------------------------------------------------------------------
// Subnets
//---------------------------------------------------------------------

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = [for k, s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  description = "List of private subnet IDs (consumed by ECS services, RDS subnet groups, interface VPC endpoints)"
  value       = [for k, s in aws_subnet.private : s.id]
}

output "public_subnets_by_az" {
  description = "Map of AZ to the list of public subnet IDs in that AZ"
  value = {
    for az in local.azs :
    az => [for k, s in aws_subnet.public : s.id if s.availability_zone == az]
  }
}

output "private_subnets_by_az" {
  description = "Map of AZ to the list of private subnet IDs in that AZ"
  value = {
    for az in local.azs :
    az => [for k, s in aws_subnet.private : s.id if s.availability_zone == az]
  }
}

//---------------------------------------------------------------------
// Route tables
//---------------------------------------------------------------------

output "public_route_table_id" {
  description = "ID of the shared public route table (null when no public subnets exist)"
  value       = try(aws_route_table.public[0].id, null)
}

output "private_route_table_ids" {
  description = "List of private route table IDs (associated with the S3/DynamoDB gateway endpoints)"
  value       = [for k, rt in aws_route_table.private : rt.id]
}

output "route_table_ids" {
  description = "All route table IDs (public + private), convenient for gateway VPC endpoint association"
  value = concat(
    [for k, rt in aws_route_table.public : rt.id],
    [for k, rt in aws_route_table.private : rt.id],
  )
}

//---------------------------------------------------------------------
// Gateways
//---------------------------------------------------------------------

output "internet_gateway_id" {
  description = "ID of the Internet Gateway (null when the VPC is fully private)"
  value       = try(aws_internet_gateway.this[0].id, null)
}

output "nat_gateway_ids" {
  description = "List of NAT gateway IDs (empty when nat_gateway = \"none\")"
  value       = [for k, ng in aws_nat_gateway.this : ng.id]
}

output "nat_public_ips" {
  description = "Elastic IPs assigned to the NAT gateways (useful for egress allow-listing)"
  value       = [for k, eip in aws_eip.nat : eip.public_ip]
}

output "default_security_group_id" {
  description = "ID of the VPC's default security group (locked down to allow no traffic — do not attach workloads to it)"
  value       = aws_default_security_group.this.id
}

//---------------------------------------------------------------------
// VPC endpoints
//---------------------------------------------------------------------

output "endpoints_security_group_id" {
  description = "ID of the shared security group attached to all interface VPC endpoints (null when no private subnets exist)"
  value       = try(aws_security_group.endpoints[0].id, null)
}

output "interface_endpoint_ids" {
  description = "Map of interface endpoint service name (e.g. ecr.api, logs) to VPC endpoint ID"
  value       = { for k, v in aws_vpc_endpoint.interface : k => v.id }
}

output "interface_endpoint_dns_entries" {
  description = "Map of interface endpoint service name to its DNS entries"
  value       = { for k, v in aws_vpc_endpoint.interface : k => v.dns_entry }
}

output "s3_endpoint_id" {
  description = "ID of the S3 gateway endpoint (null when no private subnets exist)"
  value       = try(aws_vpc_endpoint.s3[0].id, null)
}

output "s3_endpoint_prefix_list_id" {
  description = "Prefix list ID of the S3 gateway endpoint (useful for security group egress rules)"
  value       = try(aws_vpc_endpoint.s3[0].prefix_list_id, null)
}

output "dynamodb_endpoint_id" {
  description = "ID of the DynamoDB gateway endpoint (null when disabled)"
  value       = try(aws_vpc_endpoint.dynamodb[0].id, null)
}

output "dynamodb_endpoint_prefix_list_id" {
  description = "Prefix list ID of the DynamoDB gateway endpoint (useful for security group egress rules)"
  value       = try(aws_vpc_endpoint.dynamodb[0].prefix_list_id, null)
}
