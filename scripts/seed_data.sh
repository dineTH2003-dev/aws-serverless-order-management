#!/usr/bin/env bash
# seed_data.sh — Populate DynamoDB with sample orders for testing
# Usage: AWS_PROFILE=account2 ENV=dev ./scripts/seed_data.sh

set -euo pipefail

ENV=${ENV:-dev}
AWS_PROFILE=${AWS_PROFILE:-account2}
AWS_REGION=${AWS_REGION:-us-east-1}
TABLE_NAME="order-management-orders-${ENV}"

echo "Seeding DynamoDB table: ${TABLE_NAME} in ${AWS_REGION} using profile ${AWS_PROFILE}"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

aws dynamodb put-item \
  --table-name "${TABLE_NAME}" \
  --profile "${AWS_PROFILE}" \
  --region "${AWS_REGION}" \
  --item '{
    "PK":           {"S": "ORDER#seed-001"},
    "SK":           {"S": "METADATA"},
    "orderId":      {"S": "seed-001"},
    "userId":       {"S": "user-test-001"},
    "status":       {"S": "PENDING"},
    "totalAmount":  {"N": "49.99"},
    "shippingAddress": {"S": "123 Test Street, Colombo, Sri Lanka"},
    "items":        {"L": [{"M": {"productId": {"S": "prod-001"}, "name": {"S": "AWS T-Shirt"}, "quantity": {"N": "1"}, "unitPrice": {"N": "49.99"}}}]},
    "createdAt":    {"S": "'"${TIMESTAMP}"'"},
    "updatedAt":    {"S": "'"${TIMESTAMP}"'"}
  }'

echo "Seed data inserted successfully!"
