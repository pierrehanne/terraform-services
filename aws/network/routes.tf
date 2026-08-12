# ==============================================================================
# Public Routing
# ==============================================================================

resource "aws_route_table" "public" {
  count = local.create_igw ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(
    {
      Name = "${local.name_prefix}-public"
      Tier = "public"
    },
    local.common_tags
  )
}


resource "aws_route" "public_internet" {
  count = local.create_igw ? 1 : 0

  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}


resource "aws_route_table_association" "public" {
  for_each = local.public_subnets

  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public[0].id
}


# ==============================================================================
# Application Private Routing
# ==============================================================================

resource "aws_route_table" "application" {
  for_each = local.application_subnets

  vpc_id = aws_vpc.this.id

  tags = merge(
    {
      Name = "${local.name_prefix}-${each.key}"
      Tier = "application"
    },
    local.common_tags
  )
}


resource "aws_route" "application_nat" {
  for_each = local.nat_enabled ? local.application_subnets : {}

  route_table_id         = aws_route_table.application[each.key].id
  destination_cidr_block = "0.0.0.0/0"

  nat_gateway_id = contains(local.nat_keys, each.value.az) ? (
    aws_nat_gateway.this[each.value.az].id
    ) : (
    aws_nat_gateway.this[local.nat_keys[0]].id
  )
}


resource "aws_route_table_association" "application" {
  for_each = local.application_subnets

  subnet_id      = aws_subnet.application[each.key].id
  route_table_id = aws_route_table.application[each.key].id
}


# ==============================================================================
# Data Private Routing
# ==============================================================================

resource "aws_route_table" "data" {
  for_each = local.data_subnets

  vpc_id = aws_vpc.this.id

  tags = merge(
    {
      Name = "${local.name_prefix}-${each.key}"
      Tier = "data"
    },
    local.common_tags
  )
}


resource "aws_route_table_association" "data" {
  for_each = local.data_subnets

  subnet_id      = aws_subnet.data[each.key].id
  route_table_id = aws_route_table.data[each.key].id
}
