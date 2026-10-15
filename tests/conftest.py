import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import os
import sys

# Ensure src/ is on Python module search path
sys.path.insert(0, str(os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "src"))))

# Mock AWS credentials before any boto3 import
os.environ["AWS_ACCESS_KEY_ID"] = "testing"
os.environ["AWS_SECRET_ACCESS_KEY"] = "testing"
os.environ["AWS_SECURITY_TOKEN"] = "testing"
os.environ["AWS_SESSION_TOKEN"] = "testing"
os.environ["AWS_DEFAULT_REGION"] = "us-east-1"
os.environ["AWS_REGION"] = "us-east-1"
os.environ["TABLE_NAME"] = "order-management-orders-test"
os.environ["LOG_LEVEL"] = "DEBUG"

import boto3
import pytest
from moto import mock_aws


@pytest.fixture(scope="function")
def aws_credentials():
    """Mocked AWS Credentials for moto."""
    os.environ["AWS_ACCESS_KEY_ID"] = "testing"
    os.environ["AWS_SECRET_ACCESS_KEY"] = "testing"
    os.environ["AWS_SECURITY_TOKEN"] = "testing"
    os.environ["AWS_SESSION_TOKEN"] = "testing"
    os.environ["AWS_DEFAULT_REGION"] = "us-east-1"


@pytest.fixture(scope="function")
def dynamodb_table(aws_credentials):
    """Create a mock DynamoDB orders table matching our Terraform schema."""
    with mock_aws():
        dynamodb = boto3.resource("dynamodb", region_name="us-east-1")
        table = dynamodb.create_table(
            TableName="order-management-orders-test",
            KeySchema=[
                {"AttributeName": "PK", "KeyType": "HASH"},
                {"AttributeName": "SK", "KeyType": "RANGE"},
            ],
            AttributeDefinitions=[
                {"AttributeName": "PK", "AttributeType": "S"},
                {"AttributeName": "SK", "AttributeType": "S"},
                {"AttributeName": "userId", "AttributeType": "S"},
                {"AttributeName": "status", "AttributeType": "S"},
                {"AttributeName": "createdAt", "AttributeType": "S"},
            ],
            GlobalSecondaryIndexes=[
                {
                    "IndexName": "userId-createdAt-index",
                    "KeySchema": [
                        {"AttributeName": "userId", "KeyType": "HASH"},
                        {"AttributeName": "createdAt", "KeyType": "RANGE"},
                    ],
                    "Projection": {"ProjectionType": "ALL"},
                },
                {
                    "IndexName": "status-createdAt-index",
                    "KeySchema": [
                        {"AttributeName": "status", "KeyType": "HASH"},
                        {"AttributeName": "createdAt", "KeyType": "RANGE"},
                    ],
                    "Projection": {"ProjectionType": "ALL"},
                },
            ],
            BillingMode="PAY_PER_REQUEST",
        )
        table.wait_until_exists()

        # Reset module-level table cache in db.py
        import shared.db as db_mod

        db_mod._table = table
        db_mod._dynamodb = dynamodb

        yield table


@pytest.fixture
def auth_headers():
    return {
        "sub": "user-test-123",
        "email": "test@example.com",
    }


def make_apigw_event(
    method="GET",
    path="/orders",
    body=None,
    path_params=None,
    query_params=None,
    user_id="user-test-123",
):
    return {
        "httpMethod": method,
        "path": path,
        "body": (
            body
            if isinstance(body, str)
            else (None if body is None else __import__("json").dumps(body))
        ),
        "pathParameters": path_params,
        "queryStringParameters": query_params,
        "headers": {"Content-Type": "application/json"},
        "requestContext": {
            "authorizer": {
                "claims": (
                    {
                        "sub": user_id,
                        "email": f"{user_id}@example.com",
                    }
                    if user_id
                    else {}
                )
            }
        },
    }
