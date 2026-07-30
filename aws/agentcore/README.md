# AgentCore

Provisions Amazon Bedrock AgentCore infrastructure — Runtime (+ Endpoint) plus
optional Memory, Gateway and Identity — with **cybersecurity enforced by
design**, not left to the caller's discipline.

## Security by design

These are enforced with variable validation and resource preconditions, so an
insecure configuration fails at plan time rather than shipping:

- **Runtime is private by default.** `network_mode` is `VPC` unless you set
  `allow_public_network = true`. A VPC runtime *must* have `subnet_ids` and
  `security_group_ids` — a precondition blocks the "VPC mode, no subnets" trap.
- **Inbound calls must authenticate.** A `jwt_authorizer` is required unless you
  explicitly opt into `allow_public_network`. No accidental unauthenticated
  runtime.
- **Invoke allow-list.** `invoke_principal_arns` attaches an AgentCore resource
  policy scoping who may call `InvokeAgentRuntime`.
- **CMK everywhere.** Memory (`encryption_key_arn`), Gateway (`kms_key_arn`) and
  the credential token vault are all encrypted with the supplied customer-managed
  key; each is precondition-guarded to require `kms_key_arn`.
- **Secrets never in state.** Identity credential providers accept only
  write-only secret values (`client_secret_wo`, `api_key_wo`, with `*_wo_version`
  to rotate). The plaintext-in-state arguments are not exposed by this module.
- **Least-privilege execution role.** When you don't supply one, the module
  creates a role scoped to the ECR repository (image pull), CloudWatch Logs, the
  KMS key, and any statements you add — with source-account/source-arn trust
  conditions.

## Components & dependencies

- **Runtime + Endpoint** — always created. The endpoint is the invocable
  interface bound to the runtime.
- **Memory (+ strategies)** — optional (`memory != null`). Short-term event store
  with optional long-term strategies (SEMANTIC/SUMMARIZATION/…).
- **Gateway** — optional (`gateway != null`). Fronts tools as MCP with JWT/IAM
  inbound auth. Add gateway *targets* (the individual tools) against the exported
  `gateway_id`; their Lambda/OpenAPI/MCP schemas are application-specific.
- **Identity** — optional (`identity != null`). A workload identity plus
  outbound OAuth2 / API-key credential providers held in the CMK-encrypted token
  vault. The module wires the internal dependency chain (token vault CMK →
  credential providers) for you.

## Usage

```hcl
module "agentcore" {
  source = "../agentcore"

  project     = "acme"
  environment = "production"
  name        = "assistant"

  subnet_ids         = module.network.private_subnet_ids
  security_group_ids = [aws_security_group.agent.id]

  runtime            = { container_uri = "${module.ecr.repository_url}:1.0.0" }
  ecr_repository_arn = module.ecr.repository_arn

  jwt_authorizer = {
    discovery_url    = "https://<issuer>/.well-known/openid-configuration"
    allowed_audience = ["acme-agent"]
  }

  invoke_principal_arns = ["arn:aws:iam::111122223333:role/acme-agent-caller"]

  tags = { ManagedBy = "terraform" }
}
```

- [`examples/runtime-only`](./examples/runtime-only) — minimal secure VPC runtime.
- [`examples/full-stack`](./examples/full-stack) — runtime + memory + gateway + identity.

## Composition

- **network** → `subnet_ids` (private), and a security group for
  `security_group_ids`.
- **kms** → `kms_key_arn` for Memory, Gateway and the token vault.
- **ecr** → the runtime `container_uri` and `ecr_repository_arn`.
- **cognito** (or any OIDC IdP) → the `jwt_authorizer.discovery_url`.

## Notes

- **Provider pin:** this module requires `aws >= 6.57` — the
  `aws_bedrockagentcore_*` resources landed after 6.0.
- **Runtime artifact:** provide exactly one of `runtime.container_uri` (ECR
  image) or `runtime.code` (S3 zip + `entry_point` + `runtime`); a validation
  enforces this.
- **S3 gateway endpoint:** VPC runtimes created on/after 2026-05-05 no longer get
  a service-managed S3 gateway endpoint. Provision your own in the VPC (the
  `network` module's S3 gateway endpoint covers this) so the runtime can reach S3.
- **Gateway targets** are intentionally not modelled here — add
  `aws_bedrockagentcore_gateway_target` resources against `gateway_id` in the
  caller, since tool schemas are application-specific.
- **Unconfirmed at authoring time** (verify against current AWS docs before
  relying on them): the exact inbound transport for runtime invocation
  (dedicated PrivateLink vs. the regional `bedrock-agentcore` endpoint gated by
  IAM/JWT). The module enforces VPC placement + JWT auth + a resource policy
  regardless.

<!-- BEGIN_TF_DOCS -->
<!-- terraform-docs will populate inputs/outputs here on pre-commit -->
<!-- END_TF_DOCS -->
