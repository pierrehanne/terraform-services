# ==============================================================================
# VPC
# ==============================================================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}


output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}


output "vpc_arn" {
  description = "ARN of the VPC"
  value       = aws_vpc.this.arn
}


output "availability_zones" {
  description = "Availability Zones used by the network"
  value       = local.azs
}


# ==============================================================================
# Public Subnets
# ==============================================================================

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = [for subnet in aws_subnet.public : subnet.id]
}


output "public_subnets_by_az" {
  description = "Map of Availability Zone to public subnet IDs"

  value = {
    for az in local.azs :
    az => [
      for subnet in aws_subnet.public :
      subnet.id
      if subnet.availability_zone == az
    ]
  }
}


# ==============================================================================
# Application Subnets
# ==============================================================================

output "application_subnet_ids" {
  description = "List of private application subnet IDs"
  value       = [for subnet in aws_subnet.application : subnet.id]
}


output "application_subnets_by_az" {
  description = "Map of Availability Zone to application subnet IDs"

  value = {
    for az in local.azs :
    az => [
      for subnet in aws_subnet.application :
      subnet.id
      if subnet.availability_zone == az
    ]
  }
}


# ==============================================================================
# Data Subnets
# ==============================================================================

output "data_subnet_ids" {
  description = "List of private data subnet IDs"
  value       = [for subnet in aws_subnet.data : subnet.id]
}


output "data_subnets_by_az" {
  description = "Map of Availability Zone to data subnet IDs"

  value = {
    for az in local.azs :
    az => [
      for subnet in aws_subnet.data :
      subnet.id
      if subnet.availability_zone == az
    ]
  }
}


# ==============================================================================
# All Private Subnets
# ==============================================================================

output "private_subnet_ids" {
  description = "List of all private subnet IDs (application + data)"

  value = concat(
    [for subnet in aws_subnet.application : subnet.id],
    [for subnet in aws_subnet.data : subnet.id],
  )
}


output "private_subnets_by_az" {
  description = "Map of Availability Zone to all private subnet IDs"

  value = {
    for az in local.azs :
    az => concat(
      [
        for subnet in aws_subnet.application :
        subnet.id
        if subnet.availability_zone == az
      ],
      [
        for subnet in aws_subnet.data :
        subnet.id
        if subnet.availability_zone == az
      ],
    )
  }
}


# ==============================================================================
# Route Tables
# ==============================================================================

output "public_route_table_id" {
  description = "ID of the shared public route table (null when no public subnets exist)"
  value       = try(aws_route_table.public[0].id, null)
}


output "application_route_table_ids" {
  description = "Map of application subnet key to its route table ID"

  value = {
    for key, route_table in aws_route_table.application :
    key => route_table.id
  }
}


output "data_route_table_ids" {
  description = "Map of data subnet key to its route table ID"

  value = {
    for key, route_table in aws_route_table.data :
    key => route_table.id
  }
}


output "private_route_table_ids" {
  description = "List of all private route table IDs"

  value = concat(
    [for route_table in aws_route_table.application : route_table.id],
    [for route_table in aws_route_table.data : route_table.id],
  )
}


output "route_table_ids" {
  description = "All route table IDs (public + application + data)"

  value = concat(
    [for route_table in aws_route_table.public : route_table.id],
    [for route_table in aws_route_table.application : route_table.id],
    [for route_table in aws_route_table.data : route_table.id],
  )
}


# ==============================================================================
# Gateways
# ==============================================================================

output "internet_gateway_id" {
  description = "ID of the Internet Gateway (null when no public subnets exist)"
  value       = try(aws_internet_gateway.this[0].id, null)
}


output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs (empty when NAT is disabled)"
  value       = [for gateway in aws_nat_gateway.this : gateway.id]
}


output "nat_public_ips" {
  description = "Elastic IPs assigned to NAT Gateways"
  value       = [for eip in aws_eip.nat : eip.public_ip]
}


output "default_security_group_id" {
  description = "ID of the VPC default security group"
  value       = aws_default_security_group.this.id
}


# ==============================================================================
# VPC Endpoints
# ==============================================================================

output "endpoints_security_group_id" {
  description = "ID of the shared security group attached to interface VPC endpoints"

  value = try(
    aws_security_group.endpoints[0].id,
    null
  )
}


output "interface_endpoint_ids" {
  description = "Map of interface endpoint service name to VPC endpoint ID"

  value = {
    for service, endpoint in aws_vpc_endpoint.interface :
    service => endpoint.id
  }
}


output "interface_endpoint_dns_entries" {
  description = "Map of interface endpoint service name to DNS entries"

  value = {
    for service, endpoint in aws_vpc_endpoint.interface :
    service => endpoint.dns_entry
  }
}


output "s3_endpoint_id" {
  description = "ID of the S3 gateway endpoint"

  value = try(
    aws_vpc_endpoint.s3[0].id,
    null
  )
}


output "s3_endpoint_prefix_list_id" {
  description = "Prefix list ID of the S3 gateway endpoint"

  value = try(
    aws_vpc_endpoint.s3[0].prefix_list_id,
    null
  )
}


output "dynamodb_endpoint_id" {
  description = "ID of the DynamoDB gateway endpoint (null when disabled)"

  value = try(
    aws_vpc_endpoint.dynamodb[0].id,
    null
  )
}


output "dynamodb_endpoint_prefix_list_id" {
  description = "Prefix list ID of the DynamoDB gateway endpoint"

  value = try(
    aws_vpc_endpoint.dynamodb[0].prefix_list_id,
    null
  )
}
