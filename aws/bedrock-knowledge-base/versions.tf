terraform {
  # S3 Vectors support (aws_s3vectors_* and the knowledge base
  # s3_vectors_configuration block) landed well after provider 6.0, so pin to a
  # version known to carry it rather than the repo-wide ">= 6.57".
  required_version = ">= 1.15"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.57"
    }
  }
}
