#!/bin/bash
set -euo pipefail

# ── System setup ──────────────────────────────────────────────────────────────
yum update -y
yum install -y httpd curl

# ── CloudWatch agent ──────────────────────────────────────────────────────────
yum install -y amazon-cloudwatch-agent

cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CWCONFIG'
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

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s

# ── Web server ────────────────────────────────────────────────────────────────
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
AVAILABILITY_ZONE=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)

mkdir -p /var/www/html

cat > /var/www/html/index.html <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>${cluster_name} — ${environment}</title>
  <style>
    body { font-family: monospace; background: #0d1117; color: #c9d1d9; padding: 2rem; }
    .badge { display: inline-block; padding: 0.25rem 0.75rem; border-radius: 4px; font-size: 0.8rem; }
    .env-dev  { background: #1f6feb; }
    .env-prod { background: #3fb950; color: #0d1117; }
  </style>
</head>
<body>
  <h1>${cluster_name}</h1>
  <span class="badge env-${environment}">${environment}</span>
  <p>Instance: <code>$INSTANCE_ID</code></p>
  <p>AZ: <code>$AVAILABILITY_ZONE</code></p>
  <p>Port: <code>${server_port}</code></p>
  <p>Day 21 — Terraform Infrastructure Workflow</p>
</body>
</html>
HTML

# Health check endpoint
cat > /var/www/html/health <<'HEALTH'
OK
HEALTH

# Configure Apache to listen on server_port
sed -i "s/^Listen 80$/Listen ${server_port}/" /etc/httpd/conf/httpd.conf

systemctl enable httpd
systemctl start httpd