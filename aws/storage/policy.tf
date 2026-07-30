// Always-on TLS-only deny, optionally combined with a caller-supplied policy.
// aws:SecureTransport = false blocks any request made over plain HTTP.
data "aws_iam_policy_document" "bucket" {
  source_policy_documents = var.policy_json != null ? [var.policy_json] : []

  statement {
    sid    = "ModuleDenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["s3:*"]
    resources = [aws_s3_bucket.this.arn, "${aws_s3_bucket.this.arn}/*"]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  # Reject connections negotiating a TLS version below 1.2.
  statement {
    sid    = "ModuleDenyOutdatedTLS"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["s3:*"]
    resources = [aws_s3_bucket.this.arn, "${aws_s3_bucket.this.arn}/*"]

    condition {
      test     = "NumericLessThan"
      variable = "s3:TlsVersion"
      values   = ["1.2"]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.bucket.json

  # Ensure the public-access block is in place before attaching a policy so a
  # bad custom policy can never briefly expose the bucket.
  depends_on = [aws_s3_bucket_public_access_block.this]
}
