terraform {
  # The aws_bedrockagentcore_* resource family is young and landed well after
  # provider 6.0, so pin to a version known to carry it rather than ">= 6.57".
  required_version = ">= 1.15"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.57"
    }
  }
}
