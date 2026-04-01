# GCP provider — uses application default credentials
# from "gcloud auth application-default login"
# Same concept as AWS using ~/.aws/credentials
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# -----------------------------
# GCS BUCKET — equivalent to S3
# -----------------------------
# GCS bucket names must be globally unique across ALL GCP projects
# Use your project ID as prefix to ensure uniqueness
resource "google_storage_bucket" "demo" {
  name          = "${var.project_id}-dark-knight-day15"
  location      = "US"
  force_destroy = true

  # Uniform access = IAM only, no per-object ACLs
  # This is the modern recommended approach
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  labels = {
    environment = "dev"
    challenge   = "30dayterraform"
  }
}

# -----------------------------
# GCE INSTANCE — equivalent to EC2
# e2-micro is free tier eligible
# -----------------------------
resource "google_compute_instance" "demo" {
  name         = "dark-knight-day15-vm"
  machine_type = "e2-medium"  # free tier
  zone         = var.zone

  boot_disk {
    initialize_params {
      # Debian 11 — free tier eligible
      image = "debian-cloud/debian-11"
      size  = 10  # GB
    }
  }

  network_interface {
    network = "default"

    # access_config with no arguments = ephemeral public IP
    # Remove this block for a private-only instance
    access_config {}
  }

  # Startup script — same concept as AWS user_data
  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    systemctl start nginx
    systemctl enable nginx
    echo "<h1>Hello from GCP — Dark Knight Day 15! 🚀</h1>" > /var/www/html/index.html
  EOF

  tags = ["http-server"]

  labels = {
    environment = "dev"
    challenge   = "30dayterraform"
  }
}

# Firewall rule — equivalent to AWS Security Group
# Allows HTTP traffic to instances tagged "http-server"
resource "google_compute_firewall" "allow_http" {
  name    = "dark-knight-allow-http"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  # Only applies to instances with this tag
  target_tags   = ["http-server"]
  source_ranges = ["0.0.0.0/0"]
}

# -----------------------------
# OUTPUTS
# -----------------------------
output "bucket_name" {
  description = "GCS bucket name"
  value       = google_storage_bucket.demo.name
}

output "bucket_url" {
  description = "GCS bucket URL"
  value       = google_storage_bucket.demo.url
}

output "instance_name" {
  description = "GCE instance name"
  value       = google_compute_instance.demo.name
}

output "instance_external_ip" {
  description = "External IP — wait 1-2 minutes then curl this"
  value       = google_compute_instance.demo.network_interface[0].access_config[0].nat_ip
}

output "test_command" {
  description = "Run this after apply to test nginx"
  value       = "curl http://${google_compute_instance.demo.network_interface[0].access_config[0].nat_ip}"
}