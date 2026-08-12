# ==============================================================================
# S3 Gateway Endpoint
# ==============================================================================

resource "aws_vpc_endpoint" "s3" {
  count = (local.create_endpoints && var.enable_s3_endpoint) ? 1 : 0

  vpc_id = aws_vpc.this.id

  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = local.private_route_table_ids

  tags = merge(
    {
      Name = "${local.name_prefix}-endpoint-s3"
    },
    local.common_tags
  )
}


# ==============================================================================
# DynamoDB Gateway Endpoint
# ==============================================================================

resource "aws_vpc_endpoint" "dynamodb" {
  count = (
    local.create_endpoints
    && var.enable_dynamodb_endpoint
  ) ? 1 : 0

  vpc_id = aws_vpc.this.id

  service_name      = "com.amazonaws.${data.aws_region.current.region}.dynamodb"
  vpc_endpoint_type = "Gateway"

  route_table_ids = local.private_route_table_ids

  policy = data.aws_iam_policy_document.dynamodb[0].json

  tags = merge(
    {
      Name = "${local.name_prefix}-endpoint-dynamodb"
    },
    local.common_tags
  )
}


# ==============================================================================
# DynamoDB Gateway Endpoint Policy
# ==============================================================================

data "aws_iam_policy_document" "dynamodb" {
  count = (
    local.create_endpoints
    && var.enable_dynamodb_endpoint
  ) ? 1 : 0

  statement {
    sid    = "AllowDynamoDBFromVPC"
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
      "dynamodb:DescribeTable",
    ]

    resources = (
      var.dynamodb_table_arns != null
      && length(var.dynamodb_table_arns) > 0
      ? var.dynamodb_table_arns
      : ["*"]
    )

    condition {
      test     = "StringEquals"
      variable = "aws:SourceVpc"
      values   = [aws_vpc.this.id]
    }
  }
}
