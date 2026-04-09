#!/bin/bash
# Day 22 - Optimized Web Server User Data
set -euo pipefail

# ── System setup ──────────────────────────────────────────────────────────────
yum update -y
yum install -y httpd curl

# ── CloudWatch agent ──────────────────────────────────────────────────────────
yum install -y amazon-cloudwatch-agent

# Generate CloudWatch config using the Terraform variables
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<CWCONFIG
{
  "metrics": {
    "metrics_collected": {
      "mem": {
        "measurement": ["mem_used_percent"],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": ["disk_used_percent"],
        "metrics_collection_interval": 60,
        "resources": ["/"]
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/httpd/access_log",
            "log_group_name": "/ec2/${cluster_name}/httpd/access",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/httpd/error_log",
            "log_group_name": "/ec2/${cluster_name}/httpd/error",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
CWCONFIG

# Start the CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s

# ── Web server & Metadata (IMDSv2 Secure) ────────────────────────────────────
# Fetch a session token (valid for 6 hours) to communicate with AWS Metadata Service
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# Use the token to securely fetch Instance ID and AZ
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: \$TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)
AVAILABILITY_ZONE=$(curl -H "X-aws-ec2-metadata-token: \$TOKEN" -s http://169.254.169.254/latest/meta-data/placement/availability-zone)

mkdir -p /var/www/html

# Create the dynamic landing page
cat > /var/www/html/index.html <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>${cluster_name} — ${environment}</title>
  <style>
    body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #0d1117; color: #c9d1d9; padding: 3rem; line-height: 1.6; }
    .container { max-width: 800px; margin: auto; border: 1px solid #30363d; padding: 2rem; border-radius: 8px; background: #161b22; }
    h1 { color: #58a6ff; margin-top: 0; }
    .badge { display: inline-block; padding: 0.4rem 1rem; border-radius: 20px; font-weight: bold; font-size: 0.9rem; margin-bottom: 1rem; }
    .env-dev  { background: #1f6feb; color: white; }
    .env-prod { background: #238636; color: white; }
    code { background: #21262d; padding: 0.2rem 0.4rem; border-radius: 4px; color: #ffa657; }
    hr { border: 0; border-top: 1px solid #30363d; margin: 2rem 0; }
  </style>
</head>
<body>
  <div class="container">
    <h1>${cluster_name}</h1>
    <span class="badge env-${environment}">${environment} Workspace</span>
    
    <p><strong>Deployment Info:</strong></p>
    <ul>
      <li>Instance ID: <code>\$INSTANCE_ID</code></li>
      <li>Availability Zone: <code>\$AVAILABILITY_ZONE</code></li>
      <li>Application Port: <code>${server_port}</code></li>
    </ul>

    <hr>
    <p><em>Day 22 — Integrated Infrastructure CI/CD Pipeline Active</em></p>
  </div>
</body>
</html>
HTML

# Health check endpoint for the Load Balancer
cat > /var/www/html/health <<'HEALTH'
OK
HEALTH

# Configure Apache to listen on the custom port defined in Terraform
sed -i "s/^Listen 80$/Listen ${server_port}/" /etc/httpd/conf/httpd.conf

systemctl enable httpd
systemctl start httpd
