# Bedrock Guardrails

Provisions one or more Amazon Bedrock guardrails from a single map input, each
with a published version. A guardrail bundles the safety policies you want
enforced across model prompts and responses — content filters, denied topics,
PII redaction, word lists, and contextual grounding checks — encrypted with a
customer-managed KMS key that you supply.

## Design principles

- **Map-driven, multi-guardrail** — the module iterates `var.guardrails`
  (`for_each`) so a single invocation can create any number of guardrails. The
  map key names each guardrail (folded into
  `${project}-${environment}-${key}`), so there is no separate `name` input.
- **Full policy surface** — every guardrail can declare content filters, denied
  topics, PII / sensitive-information entities, denied words plus AWS managed
  word lists, and contextual grounding filters. Each policy block is emitted
  only when its list is non-empty, so guardrails stay minimal.
- **Encryption via an injected KMS key** — the module does **not** create a key.
  It consumes an existing `kms_key_arn` (build one with the sibling
  [`kms`](../kms) module) and applies it to every guardrail, keeping key
  lifecycle and policy ownership with the caller.
- **Sensible coalesced defaults** — descriptions, blocked-input / blocked-output
  messaging, and the published version description all `coalesce()` to safe
  organizational defaults when a guardrail omits them, so the minimum viable
  entry in the map is tiny.
- **Consistent tagging** — a `common_tags` local merges `Project` /
  `Environment` with caller `tags`; each guardrail additionally gets a `Name`
  tag matching its computed name.

## Usage

```hcl
module "bedrock_guardrails" {
  source = "../bedrock-guardrails"

  project     = "acme"
  environment = "production"
  kms_key_arn = module.kms.kms_key_arn

  guardrails = {
    default = {
      description = "Baseline safety guardrail for chat assistants"

      content_filters = [
        {
          type            = "HATE"
          input_strength  = "HIGH"
          output_strength = "HIGH"
        }
      ]

      denied_topics = [
        {
          name       = "investment-advice"
          definition = "Any recommendation to buy, sell, or hold financial instruments."
          examples   = ["Should I buy this stock?"]
        }
      ]

      pii_entities = [
        {
          type   = "EMAIL"
          action = "ANONYMIZE"
        }
      ]

      managed_word_lists = ["PROFANITY"]

      contextual_grounding_filters = [
        {
          type      = "GROUNDING"
          threshold = 0.75
        }
      ]
    }
  }

  tags = { ManagedBy = "terraform" }
}
```

- [`examples/simple`](./examples/simple) — one guardrail backed by a KMS key
  created via the sibling `kms` module.

## Notes

- The `kms_key_arn` must reference an existing customer-managed KMS key. The
  module never creates or manages the key.
- `aws_bedrock_guardrail_version` does **not** accept a `tags` argument, so only
  the guardrail resource is tagged. The version resource carries just its
  `guardrail_arn` and a coalesced `description`.
- Each map entry publishes exactly one guardrail version. Changing a guardrail's
  policy configuration and re-applying produces a new immutable version.
- `managed_word_lists` defaults to `["PROFANITY"]`; set it to `[]` to opt out of
  the AWS managed profanity list for a given guardrail.

<!-- BEGIN_TF_DOCS -->
<!-- terraform-docs will populate inputs/outputs here on pre-commit -->
<!-- END_TF_DOCS -->
