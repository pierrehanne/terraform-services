// Cross-region (or same-region) replication. Enabled only when a replication
// role ARN and at least one rule are supplied. Replication requires versioning
// to be enabled on the source bucket.
resource "aws_s3_bucket_replication_configuration" "this" {
  count = local.replication_enabled ? 1 : 0

  bucket = aws_s3_bucket.this.id
  role   = var.replication_role_arn

  depends_on = [aws_s3_bucket_versioning.this]

  lifecycle {
    precondition {
      condition     = var.versioning_enabled
      error_message = "Replication requires versioning_enabled = true on the source bucket."
    }
    # SSE-KMS source objects only replicate to a KMS-encrypted destination.
    precondition {
      condition     = !local.use_kms || alltrue([for r in var.replication_rules : r.destination_kms_key_arn != null])
      error_message = "When the bucket is KMS-encrypted, each replication rule must set destination_kms_key_arn (SSE-KMS objects cannot replicate to an unencrypted destination)."
    }
  }

  dynamic "rule" {
    for_each = var.replication_rules
    content {
      id     = rule.value.id
      status = "Enabled"
      # V2 filter-based rules require a unique priority per rule. Fall back to
      # the list position when the caller doesn't set one.
      priority = coalesce(rule.value.priority, rule.key)

      filter {
        prefix = coalesce(rule.value.prefix, "")
      }

      # Required when a filter is present; replicate existing delete markers off.
      delete_marker_replication {
        status = "Disabled"
      }

      destination {
        bucket        = rule.value.destination_bucket_arn
        storage_class = rule.value.storage_class

        dynamic "encryption_configuration" {
          for_each = rule.value.destination_kms_key_arn != null ? [rule.value.destination_kms_key_arn] : []
          content {
            replica_kms_key_id = encryption_configuration.value
          }
        }
      }

      # When the source objects are SSE-KMS encrypted (this module's default),
      # they must be explicitly selected or they are silently skipped.
      dynamic "source_selection_criteria" {
        for_each = local.use_kms ? [1] : []
        content {
          sse_kms_encrypted_objects {
            status = "Enabled"
          }
        }
      }
    }
  }
}
