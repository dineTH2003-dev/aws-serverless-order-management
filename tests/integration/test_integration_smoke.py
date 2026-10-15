"""
Live End-to-End Integration Smoke Tests.
Executes against live deployed AWS infrastructure (API Gateway, Cognito, Lambda, DynamoDB, WAF).
Requires AWS credentials for account2 in us-east-1.
"""

from __future__ import annotations

import os

import boto3
import pytest
import requests

API_URL = os.environ.get("API_URL", "https://7hymqfj0bk.execute-api.us-east-1.amazonaws.com/dev")
CLIENT_ID = os.environ.get("COGNITO_CLIENT_ID", "3fpe37duct53ssg8t55rdv01nh")
TEST_USER = os.environ.get("TEST_USER", "testuser@example.com")
TEST_PASSWORD = os.environ.get("TEST_PASSWORD", "Password123!")
AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")


@pytest.fixture(scope="module")
def auth_token() -> str:
    """Authenticate with Amazon Cognito and return ID Token."""
    session = boto3.Session(
        profile_name=os.environ.get("AWS_PROFILE", "account2"),
        region_name=AWS_REGION,
    )
    cognito = session.client("cognito-idp")
    try:
        resp = cognito.initiate_auth(
            ClientId=CLIENT_ID,
            AuthFlow="USER_PASSWORD_AUTH",
            AuthParameters={"USERNAME": TEST_USER, "PASSWORD": TEST_PASSWORD},
        )
        return resp["AuthenticationResult"]["IdToken"]
    except Exception as exc:
        pytest.skip(f"Cognito live authentication unavailable: {exc}")


def test_unauthenticated_request_rejected():
    """Verify API Gateway Cognito Authorizer rejects requests without token."""
    res = requests.get(f"{API_URL}/orders")
    assert res.status_code == 401


def test_order_lifecycle_smoke(auth_token: str):
    """
    Test complete live order lifecycle:
    Create -> Retrieve -> List -> Soft Delete -> Verify Soft Deleted -> Idempotent Delete
    """
    headers = {
        "Authorization": auth_token,
        "Content-Type": "application/json",
        "X-Correlation-Id": "smoke-test-run-12345",
    }

    # 1. Create Order
    create_payload = {
        "items": [
            {
                "productId": "smoke-prod-1",
                "name": "Production Smoke Test Item",
                "quantity": 2,
                "unitPrice": 49.50,
            }
        ],
        "shippingAddress": "100 Enterprise Boulevard, New York, NY",
        "notes": "Automated smoke test order",
        "idempotencyKey": "smoke-idem-" + os.urandom(4).hex(),
    }
    create_res = requests.post(f"{API_URL}/orders", headers=headers, json=create_payload)
    assert create_res.status_code == 201, f"Create failed: {create_res.text}"
    order = create_res.json()
    order_id = order["orderId"]
    assert order["status"] == "PENDING"
    assert float(order["totalAmount"]) == 99.00
    assert order["items"][0]["quantity"] == 2

    # 2. Get Single Order
    get_res = requests.get(f"{API_URL}/orders/{order_id}", headers=headers)
    assert get_res.status_code == 200
    get_data = get_res.json()
    assert get_data["orderId"] == order_id
    assert get_data["status"] == "PENDING"

    # 3. List Orders
    list_res = requests.get(f"{API_URL}/orders", headers=headers)
    assert list_res.status_code == 200
    list_data = list_res.json()
    assert list_data["count"] >= 1
    order_ids = [o["orderId"] for o in list_data["orders"]]
    assert order_id in order_ids

    # 4. Atomic Soft Delete Order
    del_res = requests.delete(f"{API_URL}/orders/{order_id}", headers=headers)
    assert del_res.status_code == 204

    # 5. Verify Soft Delete Audit Trail (order is CANCELLED, not hard-deleted)
    get_after_del = requests.get(f"{API_URL}/orders/{order_id}", headers=headers)
    assert get_after_del.status_code == 200
    after_del_data = get_after_del.json()
    assert after_del_data["status"] == "CANCELLED"
    assert after_del_data.get("deletedAt") is not None

    # 6. Idempotent Repeat Delete
    repeat_del = requests.delete(f"{API_URL}/orders/{order_id}", headers=headers)
    assert repeat_del.status_code == 204
