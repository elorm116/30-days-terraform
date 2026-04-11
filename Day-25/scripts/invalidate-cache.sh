#!/usr/bin/env bash
# scripts/invalidate-cache.sh
# Invalidates the CloudFront cache after static website content is updated.
# Run this after terraform apply when website_content changes.
#
# Usage:
#   ./scripts/invalidate-cache.sh [env]
#   ./scripts/invalidate-cache.sh dev
#   ./scripts/invalidate-cache.sh production

set -euo pipefail

ENV="${1:-dev}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_DIR="${SCRIPT_DIR}/../envs/${ENV}"

if [[ ! -d "$ENV_DIR" ]]; then
  echo "Error: environment directory not found: $ENV_DIR"
  exit 1
fi

echo "Getting CloudFront distribution ID from Terraform state (${ENV})..."
cd "$ENV_DIR"

DIST_ID=$(terraform output -raw cloudfront_distribution_id)

if [[ -z "$DIST_ID" ]]; then
  echo "Error: could not get distribution ID from Terraform output"
  exit 1
fi

echo "Invalidating CloudFront distribution: ${DIST_ID}"
INVALIDATION=$(aws cloudfront create-invalidation \
  --distribution-id "$DIST_ID" \
  --paths "/*" \
  --output json)

INVALIDATION_ID=$(echo "$INVALIDATION" | jq -r '.Invalidation.Id')
echo "Invalidation created: ${INVALIDATION_ID}"
echo "Status: $(echo "$INVALIDATION" | jq -r '.Invalidation.Status')"
echo ""
echo "Waiting for invalidation to complete (this takes 1-5 minutes)..."
aws cloudfront wait invalidation-completed \
  --distribution-id "$DIST_ID" \
  --id "$INVALIDATION_ID"

echo "Cache invalidation complete."