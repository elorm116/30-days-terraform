#!/bin/bash
set -euo pipefail

exec > >(tee -a /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

# Bootstrap script for web server instances
# Rendered by templatefile() — variables substituted at plan time

APP_NAME="${app_name}"
ENVIRONMENT="${environment}"
SERVER_PORT="${server_port}"

retry() {
  local -r max_attempts="$1"
  local -r sleep_seconds="$2"
  shift 2

  local attempt=1
  until "$@"; do
    if [[ $attempt -ge $max_attempts ]]; then
      return 1
    fi
    attempt=$((attempt + 1))
    sleep "$sleep_seconds"
  done
}

IMDS_TOKEN=""
IMDS_TOKEN=$(curl -fsS --max-time 3 -X PUT \
  -H 'X-aws-ec2-metadata-token-ttl-seconds: 21600' \
  http://169.254.169.254/latest/api/token 2>/dev/null || true)

INSTANCE_ID="unknown"
AZ="unknown"
if [[ -n "$IMDS_TOKEN" ]]; then
  INSTANCE_ID=$(curl -fsS --max-time 3 \
    -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" \
    http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo "unknown")
  AZ=$(curl -fsS --max-time 3 \
    -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" \
    http://169.254.169.254/latest/meta-data/placement/availability-zone 2>/dev/null || echo "unknown")
fi

# Install and start Apache
# Production note: avoid full OS upgrades during bootstrap; keep startup fast and reliable.
if command -v dnf >/dev/null 2>&1; then
  retry 5 3 dnf install -y httpd
else
  retry 5 3 yum install -y httpd
fi

# Configure port if non-standard
if [ "$SERVER_PORT" != "80" ]; then
  sed -i "s/^Listen 80$/Listen $SERVER_PORT/" /etc/httpd/conf/httpd.conf
fi

systemctl enable httpd
systemctl start httpd

# Write index page — shows which instance and AZ is serving the request
# (useful for verifying load balancing distributes across AZs)
cat > /var/www/html/index.html <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>$APP_NAME — $ENVIRONMENT</title>
  <style>
    body {
      font-family: monospace;
      background: #0d1117;
      color: #e6edf3;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      margin: 0;
    }
    .card {
      background: #161b22;
      border: 1px solid #30363d;
      border-radius: 8px;
      padding: 40px 48px;
      max-width: 480px;
      text-align: center;
    }
    .badge {
      display: inline-block;
      background: #7c3aed;
      color: #fff;
      padding: 4px 14px;
      border-radius: 4px;
      font-size: 12px;
      font-weight: 700;
      letter-spacing: 1px;
      margin-bottom: 20px;
    }
    h1 { font-size: 22px; margin-bottom: 8px; }
    .meta { color: #8b949e; font-size: 13px; line-height: 1.8; }
    .highlight { color: #3fb950; }
    .divider { border: none; border-top: 1px solid #30363d; margin: 20px 0; }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">TERRAFORM · DAY 26</div>
    <h1>$APP_NAME</h1>
    <hr class="divider">
    <div class="meta">
      <div>Environment: <span class="highlight">$ENVIRONMENT</span></div>
      <div>Instance: <span class="highlight">$INSTANCE_ID</span></div>
      <div>Availability Zone: <span class="highlight">$AZ</span></div>
      <div>Port: <span class="highlight">$SERVER_PORT</span></div>
    </div>
    <hr class="divider">
    <div class="meta">Deployed via EC2 Launch Template · Auto Scaling Group · ALB</div>
  </div>
</body>
</html>
HTML

# Health check endpoint — used by the ALB target group health check
# Must return HTTP 200 for the instance to be marked healthy
cat > /var/www/html/health <<'HEALTH'
OK
HEALTH

# Simple info endpoint for debugging
cat > /var/www/html/info <<INFO
instance_id=$INSTANCE_ID
availability_zone=$AZ
environment=$ENVIRONMENT
INFO

echo "Bootstrap complete — $APP_NAME ($ENVIRONMENT) on $INSTANCE_ID in $AZ"