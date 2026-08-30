data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Two AZs is enough for the ALB and RDS subnet groups.
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  # Public: 10.0.1.0/24, 10.0.2.0/24
  # Private: 10.0.11.0/24, 10.0.12.0/24
  public_subnet_cidrs  = [for i in range(length(local.azs)) : cidrsubnet(var.vpc_cidr, 8, i + 1)]
  private_subnet_cidrs = [for i in range(length(local.azs)) : cidrsubnet(var.vpc_cidr, 8, i + 11)]

  common_tags = merge(var.tags, {
    Module = "network"
  })
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-vpc"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-igw"
  })
}

resource "aws_subnet" "public" {
  count = length(local.azs)

  vpc_id                  = aws_vpc.this.id
  availability_zone       = local.azs[count.index]
  cidr_block              = local.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-public-${local.azs[count.index]}"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  count = length(local.azs)

  vpc_id            = aws_vpc.this.id
  availability_zone = local.azs[count.index]
  cidr_block        = local.private_subnet_cidrs[count.index]

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-private-${local.azs[count.index]}"
    Tier = "private"
  })
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-nat-eip"
  })

  depends_on = [aws_internet_gateway.this]
}

# One NAT keeps costs down. Private subnets share it.
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-nat"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-public-rt"
  })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-private-rt"
  })
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
