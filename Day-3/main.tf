provider "aws" {
    region = "us-east-1"
}

resource "aws_security_group" "web-sg" {
    name       = "web-sg"
    description = "Allow HTTP traffic"

    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

    data "aws_ami" "amazon_linux" {
    most_recent = true
    owners      = ["amazon"]

    filter {
        name   = "name"
        values = ["al2023-ami-*-x86_64"]
    }

    filter {
        name   = "virtualization-type"
        values = ["hvm"]
    }
    }

resource "aws_instance" "Web-Server" {
    ami           = data.aws_ami.amazon_linux.id # Amazon Linux 2023 AMI ID
    instance_type = "t2.micro"
    security_groups = [aws_security_group.web-sg.name]
    vpc_security_group_ids = [aws_security_group.web-sg.id]

    tags = {
        Name = "Terraform-Web-Server"
    }
  
}

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
