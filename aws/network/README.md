# Network

A secure-by-default VPC module: VPC, public/private subnets across multiple
Availability Zones, route tables, Internet Gateway, optional NAT, a locked-down
default security group, VPC Flow Logs, and the VPC endpoints private workloads
need to reach AWS services without leaving the AWS network.

## Design principles

- **Private by default.** With only `private_subnet_cidrs` set, the module
  creates no Internet Gateway and no NAT. Private workloads reach AWS services
  through **VPC endpoints**, which is the cheapest and most secure posture.
- **Endpoints are enforced, not composed.** Whenever the VPC has private
  subnets, a baseline set of endpoints is **always** created and cannot be
  disabled: the **S3** gateway endpoint plus the **ecr.api**, **ecr.dkr** and
  **logs** interface endpoints. Together they guarantee that container image
  pulls and log delivery stay on PrivateLink — an ECS task never pulls an ECR
  image or ships logs through a NAT gateway. This is enforced by design so the
  cost/security best practice can't be forgotten.
- **NAT is optional and explicit** via the `nat_gateway` enum
  (`none` / `single` / `per_az`) — no hidden defaults, no per-region boolean soup.
  Even with NAT enabled, the baseline endpoints still handle ECR/S3/Logs, so NAT
  only carries genuine third-party egress.
- **Subnets are keyed, not indexed.** Each subnet is keyed `"<tier>-<index>"`
  via `for_each`, so adding or removing a CIDR never forces the recreation of
  unrelated subnets.
- **Availability Zones are discovered**, never hardcoded — the module uses the
  first `availability_zone_count` AZs returned by `aws_availability_zones`.
- **Least-privilege networking.** The VPC's default security group is locked to
  allow no traffic (CIS 4.3). Flow Logs are enabled by default for auditability.
  All interface endpoints share a single security group that allows only HTTPS
  from within the VPC.

## VPC endpoints

| Endpoint | Type | Availability |
|----------|------|--------------|
| S3 | Gateway | **Always on** (private subnets present) |
| `ecr.api`, `ecr.dkr` | Interface | **Always on** |
| `logs` (CloudWatch Logs) | Interface | **Always on** |
| `monitoring` (CloudWatch Metrics) | Interface | `enable_cloudwatch_monitoring_endpoint` |
| DynamoDB | Gateway | `enable_dynamodb_endpoint` |
| KMS | Interface | `enable_kms_endpoint` |
| Secrets Manager | Interface | `enable_secretsmanager_endpoint` |
| Transcribe | Interface | `enable_transcribe_endpoint` |
| Bedrock (5 services) | Interface | `enable_bedrock_endpoints` |

Scope the generated endpoint policies with `cloudwatch_log_group_arns` (Logs)
and `dynamodb_table_arns` (DynamoDB); both default to all-resources but stay
constrained to the VPC via `aws:SourceVpc`.

## Usage

```hcl
module "network" {
  source = "../network"

  project     = "acme"
  environment = "production"
  name        = "core"

  cidr_block              = "10.0.0.0/16"
  availability_zone_count = 2

  private_subnet_cidrs = ["10.0.0.0/20", "10.0.16.0/20"]

  tags = { ManagedBy = "terraform" }
}
```

See [`examples/simple`](./examples/simple) for a fully private VPC (baseline
endpoints on automatically), and [`examples/with-nat`](./examples/with-nat) for
a public + private topology with a NAT gateway.

## NAT strategies

| `nat_gateway` | Behaviour | When to use |
|---------------|-----------|-------------|
| `none` (default) | No NAT, no Internet egress from private subnets. | Fully private workloads reachable via VPC endpoints. Cheapest, most secure. |
| `single` | One NAT gateway shared by all private subnets. | Non-production, or cost-sensitive workloads that need occasional egress. |
| `per_az` | One NAT gateway per AZ that has a public subnet. | Production — no cross-AZ dependency or data charges, highly available. |

NAT requires at least one public subnet (to host the gateway) and at least one
private subnet (to route from); otherwise it is silently skipped.

Under `per_az`, a private subnet in an AZ that has **no** public subnet routes to
the first NAT in another AZ, incurring cross-AZ data charges. Give private
subnets public-subnet coverage in the same AZs to avoid this.

## Notes

- Public subnets set `map_public_ip_on_launch = true` (required for resources in
  a public tier to be reachable). Static analysers such as checkov flag this
  (CKV_AWS_130) — it is intentional and applies only to the public tier.
- The VPC's default security group is locked to allow no traffic; do not attach
  workloads to `default_security_group_id`. Create purpose-built security groups
  instead (e.g. the ECS module does this per service).

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
| [aws_cloudwatch_log_group.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_default_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group) | resource |
| [aws_eip.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_flow_log.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log) | resource |
| [aws_iam_role.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_internet_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_route.private_nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.public_internet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route_table.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_security_group.endpoints](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.endpoints_egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.endpoints_ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_subnet.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_vpc_endpoint.dynamodb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.interface](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_iam_policy_document.dynamodb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.flow_logs_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.logs_endpoint](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_availability_zone_count"></a> [availability\_zone\_count](#input\_availability\_zone\_count) | Number of Availability Zones to spread subnets across. Subnets are distributed round-robin over the first N AZs available in the region. | `number` | `2` | no |
| <a name="input_cidr_block"></a> [cidr\_block](#input\_cidr\_block) | IPv4 CIDR block for the VPC (e.g. "10.0.0.0/16") | `string` | n/a | yes |
| <a name="input_cloudwatch_log_group_arns"></a> [cloudwatch\_log\_group\_arns](#input\_cloudwatch\_log\_group\_arns) | Optional list of CloudWatch Log Group ARNs to scope the Logs endpoint policy to. When null or empty, the policy allows all log groups (still scoped to this VPC via aws:SourceVpc). | `list(string)` | `null` | no |
| <a name="input_dynamodb_table_arns"></a> [dynamodb\_table\_arns](#input\_dynamodb\_table\_arns) | Optional list of DynamoDB table ARNs to scope the DynamoDB endpoint policy to. When null or empty, the policy allows all tables (still scoped to this VPC via aws:SourceVpc). | `list(string)` | `null` | no |
| <a name="input_enable_bedrock_endpoints"></a> [enable\_bedrock\_endpoints](#input\_enable\_bedrock\_endpoints) | Create interface endpoints for Bedrock services (bedrock, bedrock-agent, bedrock-agent-runtime, bedrock-agentcore, bedrock-runtime). | `bool` | `false` | no |
| <a name="input_enable_cloudwatch_monitoring_endpoint"></a> [enable\_cloudwatch\_monitoring\_endpoint](#input\_enable\_cloudwatch\_monitoring\_endpoint) | Create an interface endpoint for CloudWatch Metrics (monitoring). The Logs endpoint is always created as part of the baseline. | `bool` | `false` | no |
| <a name="input_enable_dns_hostnames"></a> [enable\_dns\_hostnames](#input\_enable\_dns\_hostnames) | Whether instances receive public DNS hostnames. Required for interface VPC endpoints with private DNS. | `bool` | `true` | no |
| <a name="input_enable_dns_support"></a> [enable\_dns\_support](#input\_enable\_dns\_support) | Whether DNS resolution is supported in the VPC. Required for VPC endpoints. | `bool` | `true` | no |
| <a name="input_enable_dynamodb_endpoint"></a> [enable\_dynamodb\_endpoint](#input\_enable\_dynamodb\_endpoint) | Create a gateway endpoint for DynamoDB. | `bool` | `false` | no |
| <a name="input_enable_flow_logs"></a> [enable\_flow\_logs](#input\_enable\_flow\_logs) | Whether to enable VPC Flow Logs to CloudWatch Logs. Recommended for security auditing (AWS Well-Architected). | `bool` | `true` | no |
| <a name="input_enable_kms_endpoint"></a> [enable\_kms\_endpoint](#input\_enable\_kms\_endpoint) | Create an interface endpoint for KMS. | `bool` | `false` | no |
| <a name="input_enable_secretsmanager_endpoint"></a> [enable\_secretsmanager\_endpoint](#input\_enable\_secretsmanager\_endpoint) | Create an interface endpoint for Secrets Manager. | `bool` | `false` | no |
| <a name="input_enable_transcribe_endpoint"></a> [enable\_transcribe\_endpoint](#input\_enable\_transcribe\_endpoint) | Create an interface endpoint for Transcribe. | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (e.g., production, staging, development) | `string` | n/a | yes |
| <a name="input_flow_logs_kms_key_arn"></a> [flow\_logs\_kms\_key\_arn](#input\_flow\_logs\_kms\_key\_arn) | Optional KMS key ARN to encrypt the flow logs CloudWatch Log Group. When null, logs use default CloudWatch encryption. | `string` | `null` | no |
| <a name="input_flow_logs_retention_in_days"></a> [flow\_logs\_retention\_in\_days](#input\_flow\_logs\_retention\_in\_days) | Retention in days for the VPC Flow Logs CloudWatch Log Group. | `number` | `90` | no |
| <a name="input_flow_logs_traffic_type"></a> [flow\_logs\_traffic\_type](#input\_flow\_logs\_traffic\_type) | Type of traffic to capture in flow logs: ALL, ACCEPT, or REJECT. | `string` | `"ALL"` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the VPC, used to build resource identifiers | `string` | n/a | yes |
| <a name="input_nat_gateway"></a> [nat\_gateway](#input\_nat\_gateway) | NAT strategy for private subnet egress: "none" (no Internet egress, rely on VPC endpoints — most secure and cheapest), "single" (one shared NAT gateway — cost-effective), or "per\_az" (one NAT gateway per AZ — highly available). | `string` | `"none"` | no |
| <a name="input_private_subnet_cidrs"></a> [private\_subnet\_cidrs](#input\_private\_subnet\_cidrs) | CIDR blocks for private subnets. These host workloads (ECS, RDS, etc.) that should not be directly reachable from the Internet. | `list(string)` | `[]` | no |
| <a name="input_project"></a> [project](#input\_project) | Project name used for naming and organizing resources | `string` | n/a | yes |
| <a name="input_public_subnet_cidrs"></a> [public\_subnet\_cidrs](#input\_public\_subnet\_cidrs) | CIDR blocks for public subnets. Leave empty for a fully private VPC (recommended default). | `list(string)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags applied to all resources created by this module | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_availability_zones"></a> [availability\_zones](#output\_availability\_zones) | Availability Zones the subnets are spread across |
| <a name="output_default_security_group_id"></a> [default\_security\_group\_id](#output\_default\_security\_group\_id) | ID of the VPC's default security group (locked down to allow no traffic — do not attach workloads to it) |
| <a name="output_dynamodb_endpoint_id"></a> [dynamodb\_endpoint\_id](#output\_dynamodb\_endpoint\_id) | ID of the DynamoDB gateway endpoint (null when disabled) |
| <a name="output_dynamodb_endpoint_prefix_list_id"></a> [dynamodb\_endpoint\_prefix\_list\_id](#output\_dynamodb\_endpoint\_prefix\_list\_id) | Prefix list ID of the DynamoDB gateway endpoint (useful for security group egress rules) |
| <a name="output_endpoints_security_group_id"></a> [endpoints\_security\_group\_id](#output\_endpoints\_security\_group\_id) | ID of the shared security group attached to all interface VPC endpoints (null when no private subnets exist) |
| <a name="output_interface_endpoint_dns_entries"></a> [interface\_endpoint\_dns\_entries](#output\_interface\_endpoint\_dns\_entries) | Map of interface endpoint service name to its DNS entries |
| <a name="output_interface_endpoint_ids"></a> [interface\_endpoint\_ids](#output\_interface\_endpoint\_ids) | Map of interface endpoint service name (e.g. ecr.api, logs) to VPC endpoint ID |
| <a name="output_internet_gateway_id"></a> [internet\_gateway\_id](#output\_internet\_gateway\_id) | ID of the Internet Gateway (null when the VPC is fully private) |
| <a name="output_nat_gateway_ids"></a> [nat\_gateway\_ids](#output\_nat\_gateway\_ids) | List of NAT gateway IDs (empty when nat\_gateway = "none") |
| <a name="output_nat_public_ips"></a> [nat\_public\_ips](#output\_nat\_public\_ips) | Elastic IPs assigned to the NAT gateways (useful for egress allow-listing) |
| <a name="output_private_route_table_ids"></a> [private\_route\_table\_ids](#output\_private\_route\_table\_ids) | List of private route table IDs (associated with the S3/DynamoDB gateway endpoints) |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | List of private subnet IDs (consumed by ECS services, RDS subnet groups, interface VPC endpoints) |
| <a name="output_private_subnets_by_az"></a> [private\_subnets\_by\_az](#output\_private\_subnets\_by\_az) | Map of AZ to the list of private subnet IDs in that AZ |
| <a name="output_public_route_table_id"></a> [public\_route\_table\_id](#output\_public\_route\_table\_id) | ID of the shared public route table (null when no public subnets exist) |
| <a name="output_public_subnet_ids"></a> [public\_subnet\_ids](#output\_public\_subnet\_ids) | List of public subnet IDs |
| <a name="output_public_subnets_by_az"></a> [public\_subnets\_by\_az](#output\_public\_subnets\_by\_az) | Map of AZ to the list of public subnet IDs in that AZ |
| <a name="output_route_table_ids"></a> [route\_table\_ids](#output\_route\_table\_ids) | All route table IDs (public + private), convenient for gateway VPC endpoint association |
| <a name="output_s3_endpoint_id"></a> [s3\_endpoint\_id](#output\_s3\_endpoint\_id) | ID of the S3 gateway endpoint (null when no private subnets exist) |
| <a name="output_s3_endpoint_prefix_list_id"></a> [s3\_endpoint\_prefix\_list\_id](#output\_s3\_endpoint\_prefix\_list\_id) | Prefix list ID of the S3 gateway endpoint (useful for security group egress rules) |
| <a name="output_vpc_arn"></a> [vpc\_arn](#output\_vpc\_arn) | ARN of the VPC |
| <a name="output_vpc_cidr_block"></a> [vpc\_cidr\_block](#output\_vpc\_cidr\_block) | CIDR block of the VPC (useful for security group rules) |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID of the VPC |
<!-- END_TF_DOCS -->
