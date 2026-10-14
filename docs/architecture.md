# Architecture — Serverless Order Management API

## Overview

This application uses a fully serverless architecture on AWS. No servers to manage, no capacity planning — the infrastructure scales automatically from zero to millions of requests.

## Request Flow

1. **Client** sends an authenticated HTTPS request with a Cognito JWT Bearer token
2. **AWS WAF** inspects every request — blocks OWASP Top 10 attacks, rate-limits abusive IPs
3. **Amazon API Gateway** validates the request body/params, checks the Cognito JWT token via the Cognito Authorizer, then routes to the appropriate Lambda
4. **AWS Lambda** executes the business logic (create/read/list/delete order)
5. **Amazon DynamoDB** persists or retrieves the order data

## Security Layers

```
Layer 1 — Edge:    AWS WAF (OWASP rules, rate limiting, IP blocking)
Layer 2 — API:     Cognito JWT Authorizer (authenticated users only)
Layer 3 — Compute: IAM Least-Privilege role on Lambda (exact DynamoDB actions only)
Layer 4 — Data:    DynamoDB KMS encryption at rest + PITR enabled
```

## DynamoDB Table Design

### Primary Table: `order-management-orders-<env>`

| Key | Value Pattern | Notes |
|---|---|---|
| PK (Partition) | `ORDER#<uuid>` | Unique order identifier |
| SK (Sort) | `METADATA` | Single record per PK |

### Global Secondary Indexes

| GSI Name | Partition Key | Sort Key | Use Case |
|---|---|---|---|
| `userId-createdAt-index` | `userId` | `createdAt` | List all orders for a user |
| `status-createdAt-index` | `status` | `createdAt` | Filter orders by status |

## Lambda Functions

| Function | Handler | Trigger | DynamoDB Op |
|---|---|---|---|
| `create-order` | `src/orders/create_order.lambda_handler` | POST /orders | PutItem |
| `get-order` | `src/orders/get_order.lambda_handler` | GET /orders/{id} | GetItem |
| `list-orders` | `src/orders/list_orders.lambda_handler` | GET /orders | Query (GSI-1) |
| `delete-order` | `src/orders/delete_order.lambda_handler` | DELETE /orders/{id} | DeleteItem |

## Cost Model

| Service | Pricing Model | Estimated Cost (100K req/month) |
|---|---|---|
| Lambda | $0.20 per 1M requests + $0.0000166667/GB-s | ~$0.02 |
| API Gateway | $3.50 per million API calls | ~$0.35 |
| DynamoDB | On-demand: $1.25/million writes, $0.25/million reads | ~$0.15 |
| Cognito | Free tier: 50,000 MAU | $0.00 |
| WAF | $5/month/WebACL + $1/million requests | ~$5.10 |
| **Total** | | **~$5.62/month** |
