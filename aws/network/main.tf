# ==============================================================================
# Availability Zones
# ==============================================================================

data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}


# ==============================================================================
# Locals
# ==============================================================================

locals {
  name_prefix = "${var.project}-${var.name}"

  # Baseline tags applied to every resource.
  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
    },
    var.tags
  )

  # First N available AZs in the region.
  # Never hardcode AZ letters because AZ names differ between regions/accounts.
  azs = slice(
    data.aws_availability_zones.available.names,
    0,
    min(
      var.availability_zone_count,
      length(data.aws_availability_zones.available.names)
    )
  )

  # ---------------------------------------------------------------------------
  # Public subnets
  # ---------------------------------------------------------------------------

  public_subnets = {
    for idx, cidr in var.public_subnet_cidrs :
    "public-${idx}" => {
      cidr = cidr
      az   = local.azs[idx % length(local.azs)]
      tier = "public"
    }
  }

  # ---------------------------------------------------------------------------
  # Application private subnets
  # ---------------------------------------------------------------------------

  application_subnets = {
    for idx, cidr in var.application_subnet_cidrs :
    "application-${idx}" => {
      cidr = cidr
      az   = local.azs[idx % length(local.azs)]
      tier = "application"
    }
  }

  # ---------------------------------------------------------------------------
  # Data private subnets
  # ---------------------------------------------------------------------------

  data_subnets = {
    for idx, cidr in var.data_subnet_cidrs :
    "data-${idx}" => {
      cidr = cidr
      az   = local.azs[idx % length(local.azs)]
      tier = "data"
    }
  }

  # Internet Gateway is only required when public subnets exist.
  create_igw = length(var.public_subnet_cidrs) > 0

  # NAT is only created when:
  # - NAT is requested
  # - public subnets exist
  # - at least one private subnet exists
  nat_enabled = (
    var.nat_gateway != "none"
    && local.create_igw
    && (
      length(var.application_subnet_cidrs) > 0
      || length(var.data_subnet_cidrs) > 0
    )
  )

  # AZs that actually contain public subnets.
  public_azs = distinct([
    for subnet in local.public_subnets : subnet.az
  ])

  # NAT gateway placement:
  # - single = one NAT gateway
  # - per_az = one NAT gateway per public AZ
  nat_keys = !local.nat_enabled ? [] : (
    var.nat_gateway == "single"
    ? [local.public_azs[0]]
    : local.public_azs
  )
}


# ==============================================================================
# VPC
# ==============================================================================

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(
    {
      Name = local.name_prefix
    },
    local.common_tags
  )
}


# ==============================================================================
# Internet Gateway
# ==============================================================================

resource "aws_internet_gateway" "this" {
  count = local.create_igw ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(
    {
      Name = "${local.name_prefix}-igw"
    },
    local.common_tags
  )
}


# ==============================================================================
# Public Subnets
# ==============================================================================

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


# ==============================================================================
# Application Private Subnets
# ==============================================================================

resource "aws_subnet" "application" {
  for_each = local.application_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(
    {
      Name = "${local.name_prefix}-${each.key}"
      Tier = "application"
    },
    local.common_tags
  )
}


# ==============================================================================
# Data Private Subnets
# ==============================================================================

resource "aws_subnet" "data" {
  for_each = local.data_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(
    {
      Name = "${local.name_prefix}-${each.key}"
      Tier = "data"
    },
    local.common_tags
  )
}


# ==============================================================================
# NAT Gateway Elastic IPs
# ==============================================================================

resource "aws_eip" "nat" {
  for_each = toset(local.nat_keys)

  domain = "vpc"

  tags = merge(
    {
      Name = "${local.name_prefix}-nat-${each.key}"
    },
    local.common_tags
  )

  depends_on = [
    aws_internet_gateway.this
  ]
}


# ==============================================================================
# NAT Gateways
# ==============================================================================

resource "aws_nat_gateway" "this" {
  for_each = toset(local.nat_keys)

  # Place the NAT Gateway in a public subnet
  # belonging to the corresponding AZ.
  subnet_id = [
    for subnet in aws_subnet.public :
    subnet.id
    if subnet.availability_zone == each.key
  ][0]

  allocation_id = aws_eip.nat[each.key].id

  tags = merge(
    {
      Name = "${local.name_prefix}-nat-${each.key}"
    },
    local.common_tags
  )

  depends_on = [
    aws_internet_gateway.this
  ]
}
