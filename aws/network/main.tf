data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  name_prefix = "${var.project}-${var.name}"

  # Baseline tags applied to every resource so project/environment are always
  # discoverable without callers repeating them in var.tags.
  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
    },
    var.tags
  )

  # First N AZs available in the region. Never hardcode AZ letters — regions
  # differ in count and naming.
  azs = slice(
    data.aws_availability_zones.available.names,
    0,
    min(var.availability_zone_count, length(data.aws_availability_zones.available.names))
  )

  # Build a stable, keyed map of subnets: "<tier>-<index>" => { cidr, az, tier }.
  # Keying by a derived string (not list position) means adding or removing a
  # CIDR only touches that one subnet instead of cascading recreations.
  public_subnets = {
    for idx, cidr in var.public_subnet_cidrs :
    "public-${idx}" => {
      cidr = cidr
      az   = local.azs[idx % length(local.azs)]
      tier = "public"
    }
  }

  private_subnets = {
    for idx, cidr in var.private_subnet_cidrs :
    "private-${idx}" => {
      cidr = cidr
      az   = local.azs[idx % length(local.azs)]
      tier = "private"
    }
  }

  # An Internet Gateway is only meaningful when there are public subnets.
  create_igw = length(var.public_subnet_cidrs) > 0

  # NAT is only created when requested AND there is a public subnet to host it
  # AND private subnets that need egress.
  nat_enabled = var.nat_gateway != "none" && local.create_igw && length(var.private_subnet_cidrs) > 0

  # AZs that actually host a public subnet, used to place NAT gateways.
  public_azs = distinct([for s in local.public_subnets : s.az])

  # NAT gateway keys: one shared ("single") or one per public AZ ("per_az").
  nat_keys = !local.nat_enabled ? [] : (
    var.nat_gateway == "single" ? [local.public_azs[0]] : local.public_azs
  )
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(
    { Name = local.name_prefix },
    local.common_tags
  )
}

resource "aws_internet_gateway" "this" {
  count = local.create_igw ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(
    { Name = "${local.name_prefix}-igw" },
    local.common_tags
  )
}

//---------------------------------------------------------------------
// Subnets
//---------------------------------------------------------------------

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = merge(
    {
      Name = "${local.name_prefix}-${each.key}"
      Tier = "public"
    },
    local.common_tags
  )
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(
    {
      Name = "${local.name_prefix}-${each.key}"
      Tier = "private"
    },
    local.common_tags
  )
}

//---------------------------------------------------------------------
// NAT gateways + their Elastic IPs (one per nat_keys entry)
//---------------------------------------------------------------------

resource "aws_eip" "nat" {
  for_each = toset(local.nat_keys)

  domain = "vpc"

  tags = merge(
    { Name = "${local.name_prefix}-nat-${each.key}" },
    local.common_tags
  )

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  for_each = toset(local.nat_keys)

  # Place each NAT in a public subnet in its AZ.
  subnet_id     = [for k, s in aws_subnet.public : s.id if s.availability_zone == each.key][0]
  allocation_id = aws_eip.nat[each.key].id

  tags = merge(
    { Name = "${local.name_prefix}-nat-${each.key}" },
    local.common_tags
  )

  depends_on = [aws_internet_gateway.this]
}
