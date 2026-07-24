variable "project" {
  description = "Project used for naming resources created by this module"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where endpoints and security groups will be created"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC, used to scope security group ingress/egress rules"
  type        = string
}

variable "aws_region" {
  description = "AWS region used to build VPC endpoint service names (eg eu-west-1)"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs to associate with interface endpoints"
  type        = list(string)
}

variable "route_table_ids" {
  description = "List of route table IDs to associate with gateway endpoints (S3, DynamoDB)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags applied to all resources created by this module"
  type        = map(string)
  default     = {}
}


variable "cloudwatch_log_group_arns" {
  description = "Optional list of CloudWatch Log Group ARNs to scope the logs endpoint policy to If null or empty, the policy falls back to allowing all resources (still scoped to the VPC via aws:SourceVpc)"
  type        = list(string)
  default     = null
}

variable "enable_bedrock_endpoints" {
  description = "Whether to create interface endpoints for Bedrock services (bedrock, bedrock-agent, bedrock-agent-runtime, bedrock-agentcore, bedrock-runtime)"
  type        = bool
  default     = false
}

variable "enable_cloudwatch_endpoints" {
  description = "Whether to create interface endpoints for CloudWatch (logs and monitoring)"
  type        = bool
  default     = false
}

variable "enable_ecr_endpoints" {
  description = "Whether to create interface endpoints for ECR (ecrapi, ecrdkr) Requires the S3 gateway endpoint (enable_s3_endpoint) to also be enabled, since ECR stores image layers in S3"
  type        = bool
  default     = false
}

variable "enable_dynamodb_endpoint" {
  description = "Whether to create a gateway endpoint for DynamoDB"
  type        = bool
  default     = false
}

variable "enable_kms_endpoint" {
  description = "Whether to create a gateway endpoint for KMS"
  type        = bool
  default     = false
}

variable "enable_transcribe_endpoint" {
  description = "Whether to create an interface endpoint for Transcribe"
  type        = bool
  default     = false
}

variable "enable_secretsmanager_endpoint" {
  description = "Whether to create an interface endpoint for Secret Manager"
  type        = bool
  default     = false
}

variable "enable_s3_endpoint" {
  description = "Whether to create a gateway endpoint for S3"
  type        = bool
  default     = false
}

variable "dynamodb_table_arns" {
  description = "Optional list of DynamoDB table ARNs to scope the endpoint policy to If null or empty, the policy falls back to allowing all resources (still scoped to the VPC via aws:SourceVpc)"
  type        = list(string)
  default     = null
}
