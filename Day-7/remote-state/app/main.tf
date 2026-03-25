provider "aws" {
  region = var.region
}

# Read the network layer's state file from S3
# This is how app knows about the VPC without hardcoding anything
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "dark-knight-terraform-state"
    key    = "remote-state/network/terraform.tfstate"
    region = "us-east-1"
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type


  # These IDs come from network/ state file — not hardcoded, not queried from AWS
  subnet_id = data.terraform_remote_state.network.outputs.subnet_id

  tags = {
    Name        = "web-${var.environment}"
    Environment = var.environment
    # Show exactly where the VPC ID came from
    VPC         = data.terraform_remote_state.network.outputs.vpc_id
  }
}