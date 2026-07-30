//---------------------------------------------------------------------
// Public routing: one shared route table, default route to the IGW.
//---------------------------------------------------------------------

resource "aws_route_table" "public" {
  count = local.create_igw ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(
    { Name = "${local.name_prefix}-public" },
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

//---------------------------------------------------------------------
// Private routing: one route table per private subnet.
//
// A dedicated table per subnet lets each AZ route to its own NAT gateway
// (per_az strategy) without cross-AZ data charges. With no NAT the tables
// still exist (local routes only) so gateway VPC endpoints can attach.
//---------------------------------------------------------------------

resource "aws_route_table" "private" {
  for_each = local.private_subnets

  vpc_id = aws_vpc.this.id

  tags = merge(
    { Name = "${local.name_prefix}-${each.key}" },
    local.common_tags
  )
}

resource "aws_route" "private_nat" {
  for_each = local.nat_enabled ? local.private_subnets : {}

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"

  # "single" -> the one NAT; "per_az" -> the NAT in this subnet's AZ. A private
  # subnet in an AZ without its own NAT falls back to the first NAT (this incurs
  # cross-AZ data charges — give private subnets public-subnet coverage in their
  # AZ under "per_az" to avoid it).
  nat_gateway_id = contains(local.nat_keys, each.value.az) ? (
    aws_nat_gateway.this[each.value.az].id
  ) : aws_nat_gateway.this[local.nat_keys[0]].id
}

resource "aws_route_table_association" "private" {
  for_each = local.private_subnets

  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}
