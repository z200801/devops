provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "vpc_1" {
  cidr_block           = var.vpc_1.cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.vpc_1.name}"
  }
}

