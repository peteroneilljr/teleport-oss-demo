resource "aws_eip" "cluster" {
  instance = aws_instance.cluster.id
  domain   = "vpc"
}

data "aws_route53_zone" "cluster" {
  name = var.aws_route53_zone
}

# ---------------------------------------------------------------------------- #
# Create DNS records
# ---------------------------------------------------------------------------- #
resource "aws_route53_record" "cluster" {
  zone_id = data.aws_route53_zone.cluster.zone_id
  name    = var.teleport_cluster_name
  type    = "A"
  ttl     = 300
  records = [aws_eip.cluster.public_ip]
}

resource "aws_route53_record" "wildcard-cluster" {
  zone_id = data.aws_route53_zone.cluster.zone_id
  name    = "*.${var.teleport_cluster_name}"
  type    = "A"
  ttl     = 300
  records = [aws_eip.cluster.public_ip]
}
