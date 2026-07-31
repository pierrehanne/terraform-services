# Shared tflint config for both CI (.github/workflows/ci.yml) and the local
# pre-commit hook, so linting behaves identically in both places.
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.44.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
