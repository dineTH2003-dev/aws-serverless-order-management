#!/usr/bin/env bash
# setup_github_oidc.sh — Provision AWS IAM OIDC Provider & GitHub Actions Deployment Role
# Usage: AWS_PROFILE=account2 ./scripts/setup_github_oidc.sh

set -euo pipefail

AWS_PROFILE=${AWS_PROFILE:-account2}
AWS_REGION=${AWS_REGION:-us-east-1}
GITHUB_REPO="dineTH2003-dev/aws-serverless-order-management"
ROLE_NAME="github-actions-serverless-deployer"

echo "================================================================"
echo "Configuring GitHub Actions OIDC Authentication"
echo "AWS Profile: ${AWS_PROFILE}"
echo "GitHub Repo: ${GITHUB_REPO}"
echo "IAM Role:    ${ROLE_NAME}"
echo "================================================================"

ACCOUNT_ID=$(aws sts get-caller-identity --profile "${AWS_PROFILE}" --query "Account" --output text)

# 1. Create OIDC Provider for GitHub Actions if it does not exist
OIDC_PROVIDER_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
if ! aws iam get-open-id-connect-provider --open-id-connect-provider-arn "${OIDC_PROVIDER_ARN}" --profile "${AWS_PROFILE}" 2>/dev/null; then
    echo "Creating OIDC Provider for token.actions.githubusercontent.com..."
    aws iam create-open-id-connect-provider         --url "https://token.actions.githubusercontent.com"         --client-id-list "sts.amazonaws.com"         --thumbprint-list "6938fd4d98bab03faadb97b34396831e3780aea1" "1c58761a274dd023ec1e094a940704daea86e281"         --profile "${AWS_PROFILE}"
else
    echo "OIDC Provider already exists."
fi

# 2. Trust Policy for GitHub Actions
TRUST_POLICY=$(cat << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${OIDC_PROVIDER_ARN}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_REPO}:*"
        }
      }
    }
  ]
}
EOF
)

# 3. Create IAM Role with Trust Policy
if ! aws iam get-role --role-name "${ROLE_NAME}" --profile "${AWS_PROFILE}" 2>/dev/null; then
    echo "Creating IAM Role ${ROLE_NAME}..."
    aws iam create-role         --role-name "${ROLE_NAME}"         --assume-role-policy-document "${TRUST_POLICY}"         --description "Role for GitHub Actions to deploy serverless order management infrastructure"         --profile "${AWS_PROFILE}"
else
    echo "Updating trust policy for ${ROLE_NAME}..."
    aws iam update-assume-role-policy         --role-name "${ROLE_NAME}"         --policy-document "${TRUST_POLICY}"         --profile "${AWS_PROFILE}"
fi

# 4. Attach AdministratorAccess or custom scoped deployment policy
echo "Attaching deployment policy to ${ROLE_NAME}..."
aws iam attach-role-policy     --role-name "${ROLE_NAME}"     --policy-arn "arn:aws:iam::aws:policy/AdministratorAccess"     --profile "${AWS_PROFILE}"

echo "================================================================"
echo "GitHub Actions OIDC Setup Complete!"
echo "Role ARN: arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
echo "================================================================"
