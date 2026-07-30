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
| [aws_bedrockagentcore_agent_runtime.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bedrockagentcore_agent_runtime) | resource |
| [aws_bedrockagentcore_agent_runtime_endpoint.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bedrockagentcore_agent_runtime_endpoint) | resource |
| [aws_bedrockagentcore_api_key_credential_provider.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bedrockagentcore_api_key_credential_provider) | resource |
| [aws_bedrockagentcore_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bedrockagentcore_gateway) | resource |
| [aws_bedrockagentcore_memory.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bedrockagentcore_memory) | resource |
| [aws_bedrockagentcore_memory_strategy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bedrockagentcore_memory_strategy) | resource |
| [aws_bedrockagentcore_oauth2_credential_provider.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bedrockagentcore_oauth2_credential_provider) | resource |
| [aws_bedrockagentcore_resource_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bedrockagentcore_resource_policy) | resource |
| [aws_bedrockagentcore_token_vault_cmk.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bedrockagentcore_token_vault_cmk) | resource |
| [aws_bedrockagentcore_workload_identity.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bedrockagentcore_workload_identity) | resource |
| [aws_iam_role.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.execution_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.resource_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_execution_policy_statements"></a> [additional\_execution\_policy\_statements](#input\_additional\_execution\_policy\_statements) | Extra least-privilege IAM statements added to the module-created runtime execution role (e.g. bedrock:InvokeModel on a specific model, S3 read on the code bucket). | <pre>list(object({<br/>    sid       = optional(string)<br/>    effect    = optional(string, "Allow")<br/>    actions   = list(string)<br/>    resources = list(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_allow_public_network"></a> [allow\_public\_network](#input\_allow\_public\_network) | Escape hatch to run the runtime in PUBLIC network mode instead of inside your VPC. Off by design — leave false to keep the runtime private. | `bool` | `false` | no |
| <a name="input_ecr_repository_arn"></a> [ecr\_repository\_arn](#input\_ecr\_repository\_arn) | ARN of the ECR repository the runtime image is pulled from. Used to scope the module-created execution role's ecr:BatchGetImage / GetDownloadUrlForLayer. Required when runtime.container\_uri is set and no execution\_role\_arn is supplied. | `string` | `null` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (e.g., production, staging, development) | `string` | n/a | yes |
| <a name="input_gateway"></a> [gateway](#input\_gateway) | Optional AgentCore Gateway fronting tools as MCP. authorizer\_type is<br/>CUSTOM\_JWT or AWS\_IAM. role\_arn is the gateway's execution role. When<br/>authorizer\_type is CUSTOM\_JWT, jwt is required. | <pre>object({<br/>    role_arn        = string<br/>    authorizer_type = optional(string, "AWS_IAM")<br/>    jwt = optional(object({<br/>      discovery_url    = string<br/>      allowed_audience = optional(list(string), [])<br/>      allowed_clients  = optional(list(string), [])<br/>      allowed_scopes   = optional(list(string), [])<br/>    }))<br/>    mcp_instructions = optional(string)<br/>  })</pre> | `null` | no |
| <a name="input_identity"></a> [identity](#input\_identity) | Optional Identity plane. workload\_return\_urls constrains OAuth2 return URLs<br/>for the agent's workload identity. credential\_providers hold downstream<br/>(outbound) secrets in the token vault; secrets are supplied as write-only<br/>values (never stored in Terraform state). For each provider set exactly the<br/>secret matching its kind: oauth2 uses client\_id\_wo/client\_secret\_wo, api\_key<br/>uses api\_key\_wo. Bump *\_wo\_version to rotate. | <pre>object({<br/>    create_workload_identity = optional(bool, true)<br/>    workload_return_urls     = optional(list(string), [])<br/><br/>    oauth2_providers = optional(map(object({<br/>      vendor                        = string # CustomOauth2 | GithubOauth2 | GoogleOauth2 | MicrosoftOauth2 | SalesforceOauth2 | SlackOauth2<br/>      client_id_wo                  = string<br/>      client_secret_wo              = string<br/>      client_credentials_wo_version = number<br/>      discovery_url                 = optional(string)<br/>    })), {})<br/><br/>    api_key_providers = optional(map(object({<br/>      api_key_wo         = string<br/>      api_key_wo_version = number<br/>    })), {})<br/>  })</pre> | `null` | no |
| <a name="input_invoke_principal_arns"></a> [invoke\_principal\_arns](#input\_invoke\_principal\_arns) | IAM principal ARNs allowed to invoke the runtime, enforced via an AgentCore resource policy. Empty creates no resource policy (rely on the JWT authorizer + IAM identity policies instead). | `list(string)` | `[]` | no |
| <a name="input_jwt_authorizer"></a> [jwt\_authorizer](#input\_jwt\_authorizer) | OIDC/JWT inbound authorizer for the runtime. Required unless allow\_public\_network is true (a private runtime still must authenticate callers). discovery\_url is the OIDC discovery endpoint; scope access with allowed\_audience / allowed\_clients. | <pre>object({<br/>    discovery_url    = string<br/>    allowed_audience = optional(list(string), [])<br/>    allowed_clients  = optional(list(string), [])<br/>    allowed_scopes   = optional(list(string), [])<br/>  })</pre> | `null` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | ARN of the customer-managed KMS key (from the kms module) used to encrypt the Gateway, Memory and the credential token vault. Required whenever gateway, memory or identity.credential\_providers are configured. | `string` | `null` | no |
| <a name="input_memory"></a> [memory](#input\_memory) | Optional AgentCore Memory. event\_expiry\_days governs short-term event<br/>retention (7-365). strategies configure long-term memory; each key is a<br/>strategy name and type is SEMANTIC \| SUMMARIZATION \| USER\_PREFERENCE \|<br/>EPISODIC. memory\_execution\_role\_arn is required when any strategy uses model<br/>processing. | <pre>object({<br/>    event_expiry_days         = optional(number, 90)<br/>    memory_execution_role_arn = optional(string)<br/>    strategies = optional(map(object({<br/>      type       = string<br/>      namespaces = optional(list(string), [])<br/>    })), {})<br/>  })</pre> | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Agent name, used to build the runtime and related identifiers | `string` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | Project name used for naming and organizing resources | `string` | n/a | yes |
| <a name="input_runtime"></a> [runtime](#input\_runtime) | Runtime definition. Provide exactly one artifact:<br/>  - container\_uri: an ECR image URI, OR<br/>  - code: { s3\_bucket, s3\_prefix, s3\_version\_id, entry\_point, runtime } where<br/>    runtime is one of PYTHON\_3\_10..PYTHON\_3\_13.<br/>server\_protocol is HTTP \| MCP \| A2A \| AGUI. | <pre>object({<br/>    container_uri = optional(string)<br/>    code = optional(object({<br/>      s3_bucket     = string<br/>      s3_prefix     = string<br/>      s3_version_id = optional(string)<br/>      entry_point   = list(string)<br/>      runtime       = string<br/>    }))<br/>    server_protocol       = optional(string, "HTTP")<br/>    environment_variables = optional(map(string), {})<br/>    execution_role_arn    = optional(string) # created internally when null<br/>  })</pre> | n/a | yes |
| <a name="input_security_group_ids"></a> [security\_group\_ids](#input\_security\_group\_ids) | Security group IDs attached to the runtime's ENIs. Required unless allow\_public\_network is true. | `list(string)` | `[]` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Private subnet IDs the runtime's ENIs are placed in. Required unless allow\_public\_network is true. | `list(string)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags applied to all resources created by this module | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_key_credential_provider_arns"></a> [api\_key\_credential\_provider\_arns](#output\_api\_key\_credential\_provider\_arns) | Map of API-key credential provider name to ARN |
| <a name="output_execution_role_arn"></a> [execution\_role\_arn](#output\_execution\_role\_arn) | ARN of the runtime execution role (module-created or supplied) |
| <a name="output_gateway_arn"></a> [gateway\_arn](#output\_gateway\_arn) | ARN of the AgentCore Gateway (null when gateway is not configured) |
| <a name="output_gateway_id"></a> [gateway\_id](#output\_gateway\_id) | ID of the AgentCore Gateway (null when gateway is not configured). Add gateway targets against this. |
| <a name="output_gateway_url"></a> [gateway\_url](#output\_gateway\_url) | MCP URL of the AgentCore Gateway (null when gateway is not configured) |
| <a name="output_identity_workload_arn"></a> [identity\_workload\_arn](#output\_identity\_workload\_arn) | ARN of the explicitly-created workload identity (null when not created) |
| <a name="output_memory_arn"></a> [memory\_arn](#output\_memory\_arn) | ARN of the AgentCore Memory (null when memory is not configured) |
| <a name="output_memory_id"></a> [memory\_id](#output\_memory\_id) | ID of the AgentCore Memory (null when memory is not configured) |
| <a name="output_oauth2_credential_provider_arns"></a> [oauth2\_credential\_provider\_arns](#output\_oauth2\_credential\_provider\_arns) | Map of OAuth2 credential provider name to ARN |
| <a name="output_runtime_arn"></a> [runtime\_arn](#output\_runtime\_arn) | ARN of the AgentCore runtime |
| <a name="output_runtime_endpoint_arn"></a> [runtime\_endpoint\_arn](#output\_runtime\_endpoint\_arn) | ARN of the runtime endpoint (the invocable interface) |
| <a name="output_runtime_id"></a> [runtime\_id](#output\_runtime\_id) | ID of the AgentCore runtime |
| <a name="output_runtime_version"></a> [runtime\_version](#output\_runtime\_version) | Version of the AgentCore runtime |
| <a name="output_workload_identity_arn"></a> [workload\_identity\_arn](#output\_workload\_identity\_arn) | ARN of the workload identity the runtime auto-creates (used by the Identity plane) |
<!-- END_TF_DOCS -->
