provider "aws" {
  region = "us-east-1"
}

# 1. Automatically find your Default VPC
data "aws_vpc" "default" {
  default = true
}

# 2. Security Group (The "Bouncer")
resource "aws_security_group" "web-sg" {
  name        = "web-server-sg"
  description = "Allow HTTP inbound traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. Data Source for the latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# 4. My Web Server 
resource "aws_instance" "web-server" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  
  # Using the Security Group ID is best practice
  vpc_security_group_ids = [aws_security_group.web-sg.id]

  # This script runs on boot to install Apache and create your page
  user_data = <<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello from 30 Days Terraform Challenge 🚀</h1>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "Terraform-Web-Server"
  }
}

# 5. Output the Public IP so you can test it immediately
output "ec2_instance_ip" {
  description = "Public IP of the web server"
  value = aws_instance.web-server.public_ip
}