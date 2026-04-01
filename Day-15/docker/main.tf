# Docker provider connects to your local Docker daemon
# No credentials needed — it uses your running Docker Desktop
# The empty provider block means "use defaults" which is
# the local Docker socket at unix:///var/run/docker.sock
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.9.0"
    }
  }
}

provider "docker" {}

# docker_image pulls the image from Docker Hub
# keep_locally = false means when you run terraform destroy
# Terraform will also remove the image from your local machine
# Set keep_locally = true if you want to keep the image after destroy
resource "docker_image" "nginx" {
  name         = "nginx:latest"
  keep_locally = false
}

# docker_container runs a container from the image
# This is equivalent to: docker run -d -p 8080:80 --name terraform-nginx nginx
resource "docker_container" "nginx" {
  image = docker_image.nginx.image_id
  name  = "terraform-nginx"

  # Map container port 80 to host port 8080
  # internal = port inside the container
  # external = port on your Mac that forwards to the container
  ports {
    internal = 80
    external = 8080
  }
}

output "container_name" {
  description = "Name of the running container"
  value       = docker_container.nginx.name
}

output "container_ip" {
  description = "IP address of the container"
  value       = docker_container.nginx.network_data[0].ip_address
}

output "access_url" {
  description = "URL to access nginx"
  value       = "http://localhost:8080"
}