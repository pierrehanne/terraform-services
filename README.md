# Terraform Services

[![Docs](https://img.shields.io/badge/docs-GitHub%20Pages-blue?logo=materialformkdocs)](https://pierrehanne.github.io/terraform-services/)

A collection of reusable Terraform modules for provisioning AWS infrastructure with security best practices.

📖 **[Browse the documentation site](https://pierrehanne.github.io/terraform-services/)**

## Overview

This repository provides production-ready Terraform modules for common AWS services, with a focus on encryption, security, and maintainability. Each module is designed to be composable and follows Terraform best practices.

## Available Modules

### Foundation

| Module | Description | Location | Key Features |
|--------|-------------|----------|--------------|
| **Network** | Secure-by-default VPC with public/private subnets, optional NAT, flow logs | `aws/network` | Private-by-default (no IGW/NAT unless requested), AZ auto-discovery, `for_each`-keyed subnets, NAT strategy enum (none/single/per_az), locked-down default SG, built-in gateway & interface VPC endpoints |
| **KMS** | Create and manage AWS KMS encryption keys with automatic rotation and alias management | `aws/kms` | Auto rotation (configurable period), Multi-region support, Custom policies, Alias management |
| **Secrets Manager** | Create encrypted secrets in AWS Secrets Manager with dedicated KMS encryption keys | `aws/secrets-manager` | Auto KMS key creation, Custom policies, Configurable rotation, Multi-region support |
| **IAM** | Lightweight IAM role factory (roles, policies, attachments, trust) | `aws/iam` | ECS-task trust by default, typed least-privilege statements (no `*` on Allow), managed-policy attachment, permissions boundary support |

### Compute & registry

| Module | Description | Location | Key Features |
|--------|-------------|----------|--------------|
| **ECR** | Opinionated container registry | `aws/ecr` | Immutable tags + scan-on-push by default, dedicated KMS encryption, bounded lifecycle policy, typed cross-account/CI/Lambda access |
| **ECS Fargate** | Multi-service Fargate cluster | `aws/ecs-fargate` | N independent services from one map, per-service IAM/secrets/logs/SG, Container Insights, optional shared ALB (TLS-1.2+, HTTP→HTTPS), target-tracking autoscaling, deployment circuit breaker |
| **ALB** | Standalone Application Load Balancer building block | `aws/alb` | HTTPS-only with HTTP→HTTPS redirect, modern TLS policy, `drop_invalid_header_fields`, optional regional WAFv2 (on by default), consumes `dns` cert and exposes listener/SG for `ecs-fargate` |

### Networking & identity

| Module | Description | Location | Key Features |
|--------|-------------|----------|--------------|
| **DNS** | Route53 hosted zone + ACM certificate management | `aws/dns` | Create-or-reuse hosted zone, DNS-validated ACM cert, `create_before_destroy` cert replacement, optional alias records to ALB |
| **Cognito** | Cognito user pool sized as an ALB identity provider | `aws/cognito` | Confidential client for ALB `authenticate-cognito`, email sign-in, strong password policy, admin-only creation, TOTP MFA, account-enumeration protection |

### Data

| Module | Description | Location | Key Features |
|--------|-------------|----------|--------------|
| **Storage** | Secure-by-default S3 with optional analytics | `aws/storage` | Block Public Access, versioning, SSE-KMS + bucket key, TLS-1.2-only, `BucketOwnerEnforced`, unified lifecycle, logging/replication hooks, optional Glue DB + Crawler + Athena |
| **Aurora PostgreSQL** | Serverless v2 Aurora PostgreSQL cluster with dedicated KMS encryption and auto-managed master credentials | `aws/aurora-postgresql` | Serverless v2 auto-scaling, Auto-generated password stored in Secrets Manager, Dedicated KMS key via `kms` module, Configurable security group (SG or CIDR ingress), Parameter group family derived from engine version |

### AI & serverless

| Module | Description | Location | Key Features |
|--------|-------------|----------|--------------|
| **Bedrock Guardrail** | Create and manage AWS Bedrock Guardrails with enterprise AI governance | `aws/bedrock-guardrails` | Content filtering, PII detection & masking, Topic restrictions, Custom & managed word lists, Contextual grounding, Automatic guardrail versioning |
| **Bedrock Knowledge Base** | Amazon Bedrock Knowledge Bases backed by S3 Vectors | `aws/bedrock-knowledge-base` | S3 Vectors store (no OpenSearch/RDS to run), N knowledge bases per instance, CMK encryption, least-privilege per-KB service role |
| **AgentCore** | Amazon Bedrock AgentCore runtime with security enforced by design | `aws/agentcore` | Private VPC runtime by default, mandatory JWT authorizer, invoke allow-list, CMK everywhere, plan-time preconditions |
| **Lambda Layers** | Create and manage Lambda Layers with automatic build from CodeBuild | `aws/lambda-layers` | Auto build lambda layers and register to S3 |

## Getting Started

1. Clone this repository
2. Choose the module you need
3. Reference it in your Terraform configuration
4. Configure the required variables
5. Run `terraform init` and `terraform apply`
