provider "aws" {
  region = var.region
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name        = "vpc-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.subnet_cidr
  availability_zone = "us-east-1a" # This is a hardcoded value for demo purposes only — not best practice


  tags = {
    Name        = "subnet-${var.environment}"
    Environment = var.environment
  }
}