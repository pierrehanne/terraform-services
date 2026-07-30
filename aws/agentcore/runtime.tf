// Amazon Bedrock AgentCore, composed with security enforced by design:
//   - the runtime runs inside your VPC unless you explicitly opt into PUBLIC;
//   - inbound calls must authenticate (JWT authorizer or, for public, opt-in);
//   - Gateway, Memory and the credential token vault are CMK-encrypted;
//   - downstream secrets are write-only and never land in Terraform state.
//
// This file owns the runtime (always created) and its endpoint.

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  name_prefix = "${var.project}-${var.name}"

  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
    },
    var.tags
  )

  network_mode = var.allow_public_network ? "PUBLIC" : "VPC"

  create_execution_role = var.runtime.execution_role_arn == null
  execution_role_arn    = local.create_execution_role ? aws_iam_role.execution[0].arn : var.runtime.execution_role_arn
}

resource "aws_bedrockagentcore_agent_runtime" "this" {
  agent_runtime_name = replace(local.name_prefix, "-", "_")
  role_arn           = local.execution_role_arn

  environment_variables = var.runtime.environment_variables

  agent_runtime_artifact {
    dynamic "container_configuration" {
      for_each = var.runtime.container_uri != null ? [var.runtime.container_uri] : []
      content {
        container_uri = container_configuration.value
      }
    }

    dynamic "code_configuration" {
      for_each = var.runtime.code != null ? [var.runtime.code] : []
      content {
        entry_point = code_configuration.value.entry_point
        runtime     = code_configuration.value.runtime
        code {
          s3 {
            bucket     = code_configuration.value.s3_bucket
            prefix     = code_configuration.value.s3_prefix
            version_id = code_configuration.value.s3_version_id
          }
        }
      }
    }
  }

  network_configuration {
    network_mode = local.network_mode

    dynamic "network_mode_config" {
      for_each = local.network_mode == "VPC" ? [1] : []
      content {
        subnets         = var.subnet_ids
        security_groups = var.security_group_ids
      }
    }
  }

  protocol_configuration {
    server_protocol = var.runtime.server_protocol
  }

  dynamic "authorizer_configuration" {
    for_each = var.jwt_authorizer != null ? [var.jwt_authorizer] : []
    content {
      custom_jwt_authorizer {
        discovery_url    = authorizer_configuration.value.discovery_url
        allowed_audience = length(authorizer_configuration.value.allowed_audience) > 0 ? authorizer_configuration.value.allowed_audience : null
        allowed_clients  = length(authorizer_configuration.value.allowed_clients) > 0 ? authorizer_configuration.value.allowed_clients : null
        allowed_scopes   = length(authorizer_configuration.value.allowed_scopes) > 0 ? authorizer_configuration.value.allowed_scopes : null
      }
    }
  }

  tags = local.common_tags

  lifecycle {
    # Security-by-design: a VPC runtime must have subnets + security groups.
    precondition {
      condition     = var.allow_public_network || (length(var.subnet_ids) > 0 && length(var.security_group_ids) > 0)
      error_message = "The runtime runs in a VPC by default: set subnet_ids and security_group_ids, or explicitly set allow_public_network = true."
    }

    # Security-by-design: callers must authenticate. A private runtime still
    # needs an inbound authorizer; only an explicit public opt-in may skip it.
    precondition {
      condition     = var.jwt_authorizer != null || var.allow_public_network
      error_message = "jwt_authorizer is required so inbound calls are authenticated. Only set allow_public_network = true to deliberately run without VPC isolation."
    }

    # An internally-created execution role for a container runtime needs the ECR
    # repository ARN to scope image-pull permissions.
    precondition {
      condition     = var.runtime.container_uri == null || var.runtime.execution_role_arn != null || var.ecr_repository_arn != null
      error_message = "Set ecr_repository_arn (to scope the module-created execution role) or supply runtime.execution_role_arn when using a container image."
    }
  }
}

resource "aws_bedrockagentcore_agent_runtime_endpoint" "this" {
  name             = replace(local.name_prefix, "-", "_")
  agent_runtime_id = aws_bedrockagentcore_agent_runtime.this.agent_runtime_id
}

//---------------------------------------------------------------------
// Invoke-side access control (resource policy)
//---------------------------------------------------------------------

data "aws_iam_policy_document" "resource_policy" {
  count = length(var.invoke_principal_arns) > 0 ? 1 : 0

  statement {
    sid     = "AllowInvoke"
    effect  = "Allow"
    actions = ["bedrock-agentcore:InvokeAgentRuntime"]
    principals {
      type        = "AWS"
      identifiers = var.invoke_principal_arns
    }
    resources = ["${aws_bedrockagentcore_agent_runtime.this.agent_runtime_arn}*"]
  }
}

resource "aws_bedrockagentcore_resource_policy" "this" {
  count = length(var.invoke_principal_arns) > 0 ? 1 : 0

  resource_arn = aws_bedrockagentcore_agent_runtime.this.agent_runtime_arn
  policy       = data.aws_iam_policy_document.resource_policy[0].json
}
