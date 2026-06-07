# vpc.tf
# Creates your private network on AWS
# Everything runs inside this network

# Automatically find available zones in Mumbai region
data "aws_availability_zones" "available" {
  state = "available"
}

# THE MAIN NETWORK
resource "aws_vpc" "careerlens" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.cluster_name}-vpc"
    Environment = var.environment
  }
}

# PUBLIC SUBNETS (load balancer lives here)
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.careerlens.id
  cidr_block        = "10.0.${count.index}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                        = "${var.cluster_name}-public-${count.index}"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# PRIVATE SUBNETS (worker nodes live here)
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.careerlens.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name                                        = "${var.cluster_name}-private-${count.index}"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# INTERNET GATEWAY (door to internet)
resource "aws_internet_gateway" "careerlens" {
  vpc_id = aws_vpc.careerlens.id

  tags = {
    Name = "${var.cluster_name}-igw"
  }
}

# ELASTIC IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.cluster_name}-nat-eip"
  }
}

# NAT GATEWAY (lets private nodes reach internet)
resource "aws_nat_gateway" "careerlens" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.cluster_name}-nat"
  }

  depends_on = [aws_internet_gateway.careerlens]
}

# PUBLIC ROUTE TABLE
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.careerlens.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.careerlens.id
  }

  tags = {
    Name = "${var.cluster_name}-public-rt"
  }
}

# PRIVATE ROUTE TABLE
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.careerlens.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.careerlens.id
  }

  tags = {
    Name = "${var.cluster_name}-private-rt"
  }
}

# CONNECT PUBLIC SUBNETS TO PUBLIC ROUTE TABLE
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# CONNECT PRIVATE SUBNETS TO PRIVATE ROUTE TABLE
resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
