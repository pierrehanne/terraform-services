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
<!-- terraform-docs will populate inputs/outputs here on pre-commit -->
<!-- END_TF_DOCS -->
