resource "aws_vpc" "vpc" {
  cidr_block = var.cidr_block

  tags = {
    Environment = var.env
    Name        = "${var.env}-vpc-${var.name}"
  }
}


resource "aws_subnet" "public" {
  for_each = toset(var.public_cidr_blocks)

  vpc_id     = aws_vpc.vpc.id
  cidr_block = each.key

  tags = {
    Name = "${var.env}-public-subnet-${each.key}"
  }
}


resource "aws_subnet" "private" {
  for_each = toset(var.private_cidr_blocks)

  vpc_id     = aws_vpc.vpc.id
  cidr_block = each.key

  tags = {
    Name = "${var.env}-private-subnet-${each.key}"
  }
}


resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.env}-igw-${var.name}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "10.0.1.0/24"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.env}-public-rtb-${var.name}"
  }
}

resource "aws_route_table_association" "public" {
  for_each       = toset(var.public_cidr_blocks)
  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public.id
}



resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public["10.0.1.0/24"].id

  tags = {
    Name = "${var.env}-nat-gw-${var.name}"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.igw, aws_subnet.public]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "10.0.1.0/24"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.env}-private-rtb-${var.name}"
  }
}

resource "aws_route_table_association" "private" {
  for_each       = toset(var.private_cidr_blocks)
  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private.id
}
