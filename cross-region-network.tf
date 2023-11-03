// Private RT
resource "aws_route_table" "private_cross_region_rt" {
  provider           = aws.peered
  count              =      length(local.peer_vpc_subnets_cidr)
  vpc_id             =      aws_vpc.peered_vpc.id
  tags = {
    Name = "${local.prefix}-private-rt-${element(local.peered_region_availability_zones, count.index)}"
  }
}

// Private RT Associations
resource "aws_route_table_association" "private_cross_region" {
  provider       = aws.peered
  count          = length(local.peer_vpc_subnets_cidr)
  subnet_id      = element(aws_subnet.peered_private.*.id, count.index)
  route_table_id = element(aws_route_table.private_cross_region_rt.*.id, count.index)
}

// Requestor route
resource "aws_route" "requestor_route" {
  count                     = length(local.private_subnets_cidr)
  route_table_id            =  element(aws_route_table.private_rt.*.id, count.index)
  destination_cidr_block    = var.peered_vpc_cidr_range
  vpc_peering_connection_id = aws_vpc_peering_connection.requester_connection.id
}

// Accepter route
resource "aws_route" "accepter_route" {
  provider                  = aws.peered
  count              =      length(local.peer_vpc_subnets_cidr)
  route_table_id            =  element(aws_route_table.private_cross_region_rt.*.id, count.index)
  destination_cidr_block    = var.vpc_cidr_range
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.accepter_connection.id
}

// PHZ
resource "aws_route53_zone" "private" {

  name = "s3.${var.peered_vpc_region}.amazonaws.com"

  vpc {
    vpc_id = aws_vpc.dataplane_vpc.id
  }
}

// S3 A name record 
resource "aws_route53_record" "s3" {

  zone_id  = aws_route53_zone.private.id
  name     = "s3.${var.peered_vpc_region}.amazonaws.com"
  type     = "A"

  alias {
    name     = aws_vpc_endpoint.s3.dns_entry[0].dns_name
    zone_id  = aws_vpc_endpoint.s3.dns_entry[0].hosted_zone_id
    evaluate_target_health = true
  }

  depends_on = [ 
    aws_route53_zone.private
  ]
}

// S3 wildcard record 
resource "aws_route53_record" "s3_wildcard" {

  zone_id = aws_route53_zone.private.id
  name    = "*.s3.${var.peered_vpc_region}.amazonaws.com"
  type    = "A"
  
   alias {
    name     = aws_vpc_endpoint.s3.dns_entry[0].dns_name
    zone_id  = aws_vpc_endpoint.s3.dns_entry[0].hosted_zone_id
    evaluate_target_health = true
  }

  depends_on = [ 
    aws_route53_zone.private
  ]
}