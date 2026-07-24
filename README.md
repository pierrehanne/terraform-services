# Terraform Services

A collection of reusable Terraform modules for provisioning AWS infrastructure with security best practices.

## Overview

This repository provides production-ready Terraform modules for common AWS services, with a focus on encryption, security, and maintainability. Each module is designed to be composable and follows Terraform best practices.

## Available Modules

| Module | Description | Location | Key Features |
|--------|-------------|----------|--------------|
| **Bedrock Guardrail** | Create and manage AWS Bedrock Guardrails with enterprise AI governance | `aws/bedrock-guardrails` | Content filtering, PII detection & masking, Topic restrictions, Custom & managed word lists, Contextual grounding, Automatic guardrail versioning |
| **Lambda Layers** | Create and manage Lambda Layerswith automatic build from codebuild | `aws/lambda-layers` | Auto build lambda layers and register to S3 |
| **KMS** | Create and manage AWS KMS encryption keys with automatic rotation and alias management | `aws/kms` | Auto rotation, Multi-region support, Custom policies, Alias management |
| **Secrets Manager** | Create encrypted secrets in AWS Secrets Manager with dedicated KMS encryption keys | `aws/secrets-manager` | Auto KMS key creation, Custom policies, Configurable rotation, Multi-region support |
| **VPC Endpoints** | Create VPC endpoints for AWS | `aws/vpc-endpoints` | Auto VPC Endpoints creation |

## Getting Started

1. Clone this repository
2. Choose the module you need
3. Reference it in your Terraform configuration
4. Configure the required variables
5. Run `terraform init` and `terraform apply`
