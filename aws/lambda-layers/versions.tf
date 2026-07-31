terraform {
  required_version = ">= 1.15"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.57"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2"
    }
  }
}
