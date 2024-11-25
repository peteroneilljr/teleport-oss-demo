# checks for space in availability zones
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}
locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}
# ---------------------------------------------------------------------------- #
# VPC
# ---------------------------------------------------------------------------- #
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = "${var.teleport_cluster_name}-teleport-vpc"
  cidr = var.aws_vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(var.aws_vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.aws_vpc_cidr, 8, k + 48)]
  intra_subnets   = [for k, v in local.azs : cidrsubnet(var.aws_vpc_cidr, 8, k + 52)]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = var.aws_tags

  enable_dns_hostnames    = true
  enable_dns_support      = true
  map_public_ip_on_launch = true

  default_security_group_egress = [
    {
      # allow egress
      cidr_blocks = "0.0.0.0/0",
      "from_port" : 0,
      "to_port" : 0,
      "protocol" : "-1"
    }
  ]
  default_security_group_ingress = [
    {
      # peter home
      cidr_blocks = "97.118.182.250/32",
      "from_port" : 0,
      "to_port" : 0,
      "protocol" : "tcp"
    },
    {
      # SSL
      cidr_blocks = "0.0.0.0/0",
      "from_port" : 443,
      "to_port" : 443,
      "protocol" : "tcp"
    },
    {
      # Postgresql
      cidr_blocks = "0.0.0.0/0",
      "from_port" : 5432,
      "to_port" : 5432,
      "protocol" : "tcp"
    },
    {
      # mysql
      cidr_blocks = "0.0.0.0/0",
      "from_port" : 3306,
      "to_port" : 3306,
      "protocol" : "tcp"
    },
    {
      # rdp
      cidr_blocks = "0.0.0.0/0",
      "from_port" : 3389,
      "to_port" : 3389,
      "protocol" : "tcp"
    },
    {
      # SSH
      cidr_blocks = "0.0.0.0/0",
      "from_port" : 22,
      "to_port" : 22,
      "protocol" : "tcp"
    },
    {
      # internal traffic
      cidr_blocks = "10.7.0.0/16",
      "from_port" : 0,
      "to_port" : 0,
      "protocol" : "-1"
    }
  ]

}
