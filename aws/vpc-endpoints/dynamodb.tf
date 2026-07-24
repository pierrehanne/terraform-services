
data "aws_iam_policy_document" "dynamodb" {
  count = var.enable_dynamodb_endpoint ? 1 : 0

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

    resources = var.dynamodb_table_arns != null && length(var.dynamodb_table_arns) > 0 ? var.dynamodb_table_arns : ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceVpc"
      values   = [var.vpc_id]
    }
  }
}

resource "aws_vpc_endpoint" "dynamodb" {
  count = var.enable_dynamodb_endpoint ? 1 : 0

  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.route_table_ids
  policy            = data.aws_iam_policy_document.dynamodb[0].json

  tags = merge(
    { Name = "${var.project}-endpoint-dynamodb" },
    var.tags
  )
}
