#!/usr/bin/env bash
# bootstrap_terraform_backend.sh — Provision S3 bucket and DynamoDB table for Terraform remote state
# Usage: AWS_PROFILE=account2 ./scripts/bootstrap_terraform_backend.sh

set -euo pipefail

AWS_PROFILE=${AWS_PROFILE:-account2}
AWS_REGION=${AWS_REGION:-us-east-1}

ACCOUNT_ID=$(aws sts get-caller-identity --profile "${AWS_PROFILE}" --query "Account" --output text)
BUCKET_NAME="order-management-tfstate-${ACCOUNT_ID}"
LOCK_TABLE="order-management-tfstate-lock"

echo "================================================================"
echo "Bootstrapping Terraform Remote State Backend"
echo "AWS Profile: ${AWS_PROFILE}"
echo "AWS Account: ${ACCOUNT_ID}"
echo "AWS Region:  ${AWS_REGION}"
echo "S3 Bucket:   ${BUCKET_NAME}"
echo "Lock Table:  ${LOCK_TABLE}"
echo "================================================================"

# 1. Create S3 Bucket (us-east-1 does not use LocationConstraint)
if aws s3api head-bucket --bucket "${BUCKET_NAME}" --profile "${AWS_PROFILE}" 2>/dev/null; then
    echo "S3 bucket ${BUCKET_NAME} already exists."
else
    echo "Creating S3 bucket: ${BUCKET_NAME}..."
    if [ "${AWS_REGION}" = "us-east-1" ]; then
        aws s3api create-bucket             --bucket "${BUCKET_NAME}"             --region "${AWS_REGION}"             --profile "${AWS_PROFILE}"
    else
        aws s3api create-bucket             --bucket "${BUCKET_NAME}"             --region "${AWS_REGION}"             --profile "${AWS_PROFILE}"             --create-bucket-configuration LocationConstraint="${AWS_REGION}"
    fi
fi

# 2. Enable Bucket Versioning
echo "Enabling versioning on ${BUCKET_NAME}..."
aws s3api put-bucket-versioning     --bucket "${BUCKET_NAME}"     --versioning-configuration Status=Enabled     --profile "${AWS_PROFILE}"

# 3. Enable Bucket Server-Side Encryption
echo "Enabling AES256 server-side encryption on ${BUCKET_NAME}..."
aws s3api put-bucket-encryption     --bucket "${BUCKET_NAME}"     --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }'     --profile "${AWS_PROFILE}"

# 4. Block Public Access
echo "Enabling Public Access Block on ${BUCKET_NAME}..."
aws s3api put-public-access-block     --bucket "${BUCKET_NAME}"     --public-access-block-configuration '{
        "BlockPublicAcls": true,
        "IgnorePublicAcls": true,
        "BlockPublicPolicy": true,
        "RestrictPublicBuckets": true
    }'     --profile "${AWS_PROFILE}"

# 5. Create DynamoDB Lock Table
if aws dynamodb describe-table --table-name "${LOCK_TABLE}" --region "${AWS_REGION}" --profile "${AWS_PROFILE}" 2>/dev/null; then
    echo "DynamoDB table ${LOCK_TABLE} already exists."
else
    echo "Creating DynamoDB state lock table: ${LOCK_TABLE}..."
    aws dynamodb create-table         --table-name "${LOCK_TABLE}"         --attribute-definitions AttributeName=LockID,AttributeType=S         --key-schema AttributeName=LockID,KeyType=HASH         --billing-mode PAY_PER_REQUEST         --region "${AWS_REGION}"         --profile "${AWS_PROFILE}"
fi

echo "================================================================"
echo "Terraform Remote State Backend Bootstrap Complete!"
echo "S3 Bucket:      ${BUCKET_NAME}"
echo "DynamoDB Table: ${LOCK_TABLE}"
echo "================================================================"
