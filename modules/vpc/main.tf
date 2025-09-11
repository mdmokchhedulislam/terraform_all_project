

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 2)
  public_cidrs  = var.public_subnet_cidrs
  private_cidrs = var.private_subnet_cidrs
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = true

  tags = {
    Name = "${var.cluster_name}-vpc"
  }
}



# Public subnets (one per AZ)
resource "aws_subnet" "public" {
  for_each = { for idx, az in local.azs : idx => az }

  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_cidrs[each.key]
  availability_zone       = each.value
  map_public_ip_on_launch = true

  tags = merge(
    {
      Name = "${var.cluster_name}-public-${each.value}"
    },
    # EKS expects the following tag to allow ELB on public
    {
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
      "kubernetes.io/role/elb"                    = "1"
    }
  )
}

# Private subnets (one per AZ)
resource "aws_subnet" "private" {
  for_each = { for idx, az in local.azs : idx => az }

  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_cidrs[each.key]
  availability_zone = each.value
  # Do not map public IPs for private subnets
  map_public_ip_on_launch = false

  tags = merge(
    {
      Name = "${var.cluster_name}-private-${each.value}"
    },
    # EKS internal ELB role
    {
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
      "kubernetes.io/role/internal-elb"            = "1"
    }
  )
}


# Internet Gateway for public subnets
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.cluster_name}-igw"
  }
}


# Public Route Table & route to IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.cluster_name}-public-rt"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Associate public subnets with public RT
resource "aws_route_table_association" "public_assoc" {
  for_each = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# EIP + NAT Gateway per public subnet (one NAT per AZ)

resource "aws_eip" "nat_eip" {
  for_each = aws_subnet.public
  domain   = "vpc"
  
  tags = {
    Name = "${var.cluster_name}-eip-${each.value.availability_zone}"
  }
}

resource "aws_nat_gateway" "nat" {
  for_each = aws_subnet.public

  allocation_id = aws_eip.nat_eip[each.key].id
  subnet_id     = each.value.id
  depends_on    = [aws_internet_gateway.igw]

  tags = {
    Name = "${var.cluster_name}-nat-${each.value.availability_zone}"
  }
}


# Private Route Tables — one per AZ -> point default route to NAT in same AZ
resource "aws_route_table" "private" {
  for_each = aws_subnet.private
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.cluster_name}-private-rt-${each.value.availability_zone}"
  }
}

# route 0.0.0.0/0 via NAT in same AZ
resource "aws_route" "private_nat_route" {
  for_each = aws_route_table.private

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[each.key].id
}

# Associate private subnets with corresponding private RT
resource "aws_route_table_association" "private_assoc" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}


