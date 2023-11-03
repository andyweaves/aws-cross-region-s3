resource "aws_vpc" "dataplane_vpc" {
  cidr_block           = var.vpc_cidr_range
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${local.prefix}-dataplane-vpc"
  }
}

// Private Subnets
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.dataplane_vpc.id
  count                   = length(local.private_subnets_cidr)
  cidr_block              = element(local.private_subnets_cidr, count.index)
  availability_zone       = element(local.availability_zones, count.index)
  map_public_ip_on_launch = false
  tags = {
    Name = "${local.prefix}-private-${element(local.availability_zones, count.index)}"
  }
}

// PrivateLink Subnet
resource "aws_subnet" "privatelink" {
  vpc_id                  = aws_vpc.dataplane_vpc.id
  count                   = length(local.privatelink_subnets_cidr)
  cidr_block              = element(local.privatelink_subnets_cidr, count.index)
  availability_zone       = element(local.availability_zones, count.index)
  map_public_ip_on_launch = false
  tags = {
    Name = "${local.prefix}-privatelink-${element(local.availability_zones, count.index)}"
  }
}

// Dataplane NACL
resource "aws_network_acl" "dataplane" {
  vpc_id = aws_vpc.dataplane_vpc.id
  subnet_ids = concat(aws_subnet.private[*].id)

  ingress {
    protocol   = "all"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  
  egress {
    protocol   = "all"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.vpc_cidr_range
    from_port  = 0
    to_port    = 0
  }

  dynamic "egress" {
    for_each = local.sg_egress_ports
    content {
      from_port   = egress.value
      to_port     = egress.value
      protocol    = "tcp"
      cidr_block  = "0.0.0.0/0"
      action      = "ALLOW"
      rule_no     = egress.key + 200
    }
  }

  tags = {
    Name = "${local.prefix}-nacl"
  }
}

// SG
resource "aws_security_group" "sg" {
  vpc_id = aws_vpc.dataplane_vpc.id
  depends_on  = [aws_vpc.dataplane_vpc]

  dynamic "ingress" {
    for_each = local.sg_ingress_protocol
    content {
      from_port = 0
      to_port   = 65535
      protocol  = ingress.value
      self      = true
    }
  }

  dynamic "egress" {
    for_each = local.sg_egress_protocol
    content {
      from_port = 0
      to_port   = 65535
      protocol  = egress.value
      self      = true
    }
  }

  dynamic "egress" {
    for_each = local.sg_egress_ports
    content {
      from_port   = egress.value
      to_port     = egress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  ingress {
    description      = "TLS from peered VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = [var.peered_vpc_cidr_range]
  }

  egress {
    description      = "TLS to peered VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = [var.peered_vpc_cidr_range]
  }

  tags = {
    Name = "${local.prefix}-dataplane-sg"
  }
}

// Private RT
resource "aws_route_table" "private_rt" {
  count              = length(local.private_subnets_cidr)
  vpc_id             = aws_vpc.dataplane_vpc.id
  tags = {
    Name = "${local.prefix}-private-rt-${element(local.availability_zones, count.index)}"
  }
}

// Private RT Associations
resource "aws_route_table_association" "private" {
  count          = length(local.private_subnets_cidr)
  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = element(aws_route_table.private_rt.*.id, count.index)
}

// Peered VPC
resource "aws_vpc" "peered_vpc" {
  provider             = aws.peered
  cidr_block           = var.peered_vpc_cidr_range
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${local.prefix}-${var.peered_vpc_region}-vpc"
  }
}

// Private Subnets
resource "aws_subnet" "peered_private" {
  provider = aws.peered
  vpc_id                  = aws_vpc.peered_vpc.id
  count                   = length(local.peer_vpc_subnets_cidr)
  cidr_block              = element(local.peer_vpc_subnets_cidr, count.index)
  availability_zone       = element(local.peered_region_availability_zones, count.index)
  map_public_ip_on_launch = false
  tags = {
    Name = "${local.prefix}-private-${element(local.peered_region_availability_zones, count.index)}"
  }
}

resource "aws_security_group" "s3_interface" {
  provider    = aws.peered
  name        = "allow inbound"
  vpc_id      = aws_vpc.peered_vpc.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = [var.vpc_cidr_range]
  }

  egress {
    description      = "TLS to VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = [var.vpc_cidr_range]
  }

  tags = {
    Name = "allow_tls"
  }
}

// Requester's side of the connection.
resource "aws_vpc_peering_connection" "requester_connection" {
  provider      = aws
  vpc_id        = aws_vpc.dataplane_vpc.id
  peer_vpc_id   = aws_vpc.peered_vpc.id
  peer_owner_id = data.aws_caller_identity.current.account_id
  peer_region   = var.peered_vpc_region
  auto_accept   = false
  tags = {
    Side = "Requester"
  }
}

// Accepter's side of the connection.
resource "aws_vpc_peering_connection_accepter" "accepter_connection" {
  provider                  = aws.peered
  vpc_peering_connection_id = aws_vpc_peering_connection.requester_connection.id
  auto_accept               = true
  tags = {
    Side = "Accepter"
  }
}

// S3 VPC Interface 
resource "aws_vpc_endpoint" "s3" {
  provider          = aws.peered
  vpc_id            = aws_vpc.peered_vpc.id
  service_name      = "com.amazonaws.${var.peered_vpc_region}.s3"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    aws_security_group.s3_interface.id,
  ]
  subnet_ids         = concat(aws_subnet.peered_private[*].id)

  depends_on = [
    aws_security_group.s3_interface
  ]
    tags = {
      Name = "${var.resource_prefix}-com.amazonaws.${var.peered_vpc_region}.s3"
  }
}