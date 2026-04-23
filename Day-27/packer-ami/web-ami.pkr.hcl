packer {
  required_plugins {
    amazon = {
      version = ">= 1.8.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "replica_regions" {
  type    = list(string)
  default = ["us-west-2"]
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "ami_name_prefix" {
  type    = string
  default = "web-ha"
}

data "amazon-ami" "al2023" {
  region = var.aws_region
  owners = ["amazon"]
  filters = {
    name                = "al2023-ami-2023.*-x86_64"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
    state               = "available"
  }
  most_recent = true
}

source "amazon-ebs" "web" {
  region        = var.aws_region
  instance_type = var.instance_type
  source_ami    = data.amazon-ami.al2023.id
  ssh_username  = "ec2-user"

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    http_endpoint               = "enabled"
  }

  ami_name        = "${var.ami_name_prefix}-al2023-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  ami_description = "Pre-baked web AMI (AL2023 + Apache)"
  ami_regions     = var.replica_regions

  encrypt_boot = true

  # Required when replicating an encrypted AMI across regions
  region_kms_key_ids = {
    "us-west-2" = "alias/aws/ebs"
  }

  tags = {
    Name      = "${var.ami_name_prefix}-al2023"
    BaseAMI   = data.amazon-ami.al2023.id
    BuildDate = formatdate("YYYY-MM-DD", timestamp())
    ManagedBy = "packer"
  }
}

build {
  name    = "web-ha-ami"
  sources = ["source.amazon-ebs.web"]

  # Upload placeholder HTML (file provisioner runs as ec2-user, so /tmp first)
  provisioner "file" {
    source      = "files/index.html"
    destination = "/tmp/index.html"
  }

  # System setup
  provisioner "shell" {
    inline = [
      "set -euo pipefail",
      "sudo yum update -y",
      "sudo yum install -y httpd",
      "sudo mkdir -p /var/www/html",
      "sudo mv /tmp/index.html /var/www/html/index.html",
      "echo 'OK' | sudo tee /var/www/html/health > /dev/null",
      "sudo chown -R apache:apache /var/www/html",
      "sudo systemctl enable httpd",
      "sudo systemctl start httpd",
    ]
  }

  # Security hardening
  provisioner "shell" {
    inline = [
      "set -euo pipefail",
      "sudo shred -u /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub 2>/dev/null || true",
      "sudo find /var/log -type f -exec truncate -s 0 {} \\;",
      "sudo find /root /home -name '.bash_history' -delete 2>/dev/null || true",
      "sudo cloud-init clean --logs",
    ]
  }

  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
  }
}