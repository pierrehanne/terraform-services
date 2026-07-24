# Terraform Services

A collection of reusable Terraform modules for provisioning AWS infrastructure with security best practices.

## Overview

This repository provides production-ready Terraform modules for common AWS services, with a focus on encryption, security, and maintainability. Each module is designed to be composable and follows Terraform best practices.

## Available Modules

| Module | Description | Location | Key Features |
|--------|-------------|----------|--------------|
| **Bedrock Guardrail** | Deploy and manage Amazon Bedrock Guardrail with enterprise AI governance, including optional customer-managed AWS KMS encryption | `aws/bedrock-guardrail | Content filtering, PII detection & masking, Topic restrictions, Custom & managed word lists, Contextual grounding (hallucination prevention), Automatic guardrail versioning, Optional customer-managed KMS encryption |
| **KMS** | Create and manage AWS KMS encryption keys with automatic rotation and alias management | `aws/kms` | Auto rotation, Multi-region support, Custom policies, Alias management |
| **Secrets Manager** | Create encrypted secrets in AWS Secrets Manager with dedicated KMS encryption keys | `aws/secrets-manager` | Auto KMS key creation, Custom policies, Configurable rotation, Multi-region support |
| **Secrets Manager** | Create VPC endpoints for AWS | `aws/vpc-endpoints` | Auto VPC Endpoints creation |

---

## Module Structure

Each module follows a consistent structure:

```
aws/<service>/
├── main.tf       # Primary resource definitions
├── variables.tf  # Input variables
├── outputs.tf    # Output values
└── *.tf          # Additional resource files (if needed)
```

## Best Practices

These modules follow the [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/) principles:

### Security Pillar
- **Encryption by Default:** All modules prioritize encryption at rest using KMS
- **Key Rotation:** Automatic key rotation is enabled by default (365 days for KMS, 90 days for Secrets Manager)
- **Least Privilege:** Supports custom KMS and secret policies for fine-grained access control
- **Data Protection:** Secrets are encrypted with dedicated KMS keys

### Operational Excellence Pillar
- **Infrastructure as Code:** All resources defined and managed through Terraform
- **Tagging:** All resources support tagging for better organization, cost tracking, and operational insights
- **Modularity:** Modules are designed to work independently or together
- **Documentation:** Clear variable descriptions and usage examples

### Reliability Pillar
- **Multi-Region Support:** KMS keys can be configured as multi-region for disaster recovery
- **Backup & Recovery:** Configurable recovery windows for secrets (default: immediate deletion for non-production)

### Cost Optimization Pillar
- **Resource Tagging:** Enable cost allocation and tracking through comprehensive tagging
- **Right-Sizing:** Minimal resource footprint with only necessary components

## Getting Started

1. Clone this repository
2. Choose the module you need
3. Reference it in your Terraform configuration
4. Configure the required variables
5. Run `terraform init` and `terraform apply`
