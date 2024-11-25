terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.73"
    }
  }
}
provider "aws" {
  profile = var.aws_teleport_profile

  region = var.aws_region
  default_tags {
    tags = var.aws_tags
  }
}
