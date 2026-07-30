//---------------------------------------------------------------------
// Web Application Firewall (optional, attached to the ALB).
//
// A regional WAFv2 Web ACL associated with this ALB. WAF is a Layer-7 control:
// it inspects HTTP(S) requests and blocks common web attacks, bad inputs and
// abusive request rates. It is NOT a VPC-level firewall (that is AWS Network
// Firewall, a separate network-module concern).
//
// The default posture blocks: AWS managed CommonRuleSet + KnownBadInputs run in
// block mode and a rate-based rule caps per-IP request rate. Callers can append
// their own managed rule groups (and flip any group to count mode for tuning)
// via var.waf_managed_rule_groups.
//---------------------------------------------------------------------

locals {
  waf_metric_prefix = replace("${local.name_prefix}-waf", "-", "")
}

resource "aws_wafv2_web_acl" "this" {
  count = var.enable_waf ? 1 : 0

  name        = "${local.name_prefix}-waf"
  description = "Web ACL for the ${local.name_prefix} ALB"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # AWS managed baseline: common web exploits (XSS, LFI, etc.).
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.waf_metric_prefix}CommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # AWS managed: known-bad inputs (exploitable request patterns, CVEs).
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.waf_metric_prefix}KnownBadInputs"
      sampled_requests_enabled   = true
    }
  }

  # Rate limiting: block a source IP that exceeds the threshold over 5 minutes.
  rule {
    name     = "RateLimit"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.waf_metric_prefix}RateLimit"
      sampled_requests_enabled   = true
    }
  }

  # Caller-supplied managed rule groups, appended after the baseline. Each may
  # run in block mode (override none{}) or count mode (override count{}) for
  # tuning before enforcing.
  dynamic "rule" {
    for_each = { for g in var.waf_managed_rule_groups : g.priority => g }

    content {
      name     = rule.value.name
      priority = rule.value.priority

      override_action {
        dynamic "none" {
          for_each = rule.value.override_to_count ? [] : [1]
          content {}
        }
        dynamic "count" {
          for_each = rule.value.override_to_count ? [1] : []
          content {}
        }
      }

      statement {
        managed_rule_group_statement {
          name        = rule.value.name
          vendor_name = rule.value.vendor_name
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.waf_metric_prefix}${replace(rule.value.name, "/[^a-zA-Z0-9]/", "")}"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = local.waf_metric_prefix
    sampled_requests_enabled   = true
  }

  tags = local.common_tags
}

resource "aws_wafv2_web_acl_association" "this" {
  count = var.enable_waf ? 1 : 0

  resource_arn = aws_lb.this.arn
  web_acl_arn  = aws_wafv2_web_acl.this[0].arn
}
