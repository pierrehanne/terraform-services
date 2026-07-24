variable "aws" {
  description = "AWS configuration."

  type = object({
    account_id = string
    region     = string
  })
}

variable "artifact_bucket" {
  description = "Configuration of the S3 bucket used to store built Lambda layer artifacts."
  type = object({
    name         = string
    arn          = string
    kms_key_arn  = string
    layer_prefix = string
  })
}

variable "codebuild" {
  description = "AWS CodeBuild configuration."
  type = object({
    name          = string
    image         = string
    timeout       = number
    log_retention = number
  })
}

variable "environment" {
  description = "Environment name (e.g., production, staging, development)."
  type        = string
}

variable "layers" {
  description = "Lambda layers to build and publish."

  type = map(object({
    layer_name     = string
    buildspec_path = string
    runtimes       = list(string)
    architectures  = list(string)
  }))
}

variable "project" {
  description = "Project name used for naming and organizing resources."
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
  default     = {}
}
