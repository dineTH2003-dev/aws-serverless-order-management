import json
from helpers import make_apigw_event
from orders.create_order import lambda_handler


def test_create_order_success(dynamodb_table):
    payload = {
        "items": [
            {"productId": "prod-1", "name": "Cloud Architecture Guide", "quantity": 1, "unitPrice": 49.99}
        ],
        "shippingAddress": "456 Cloud Way, Seattle, WA",
        "notes": "Leave at front door",
    }
    event = make_apigw_event(method="POST", path="/orders", body=payload, user_id="user-456")

    response = lambda_handler(event, None)
    assert response["statusCode"] == 201
    body = json.loads(response["body"])
    assert body["userId"] == "user-456"
    assert body["totalAmount"] == 49.99
    assert body["status"] == "PENDING"
    assert "orderId" in body


def test_create_order_missing_auth(dynamodb_table):
    payload = {
        "items": [{"productId": "p1", "name": "Item", "quantity": 1, "unitPrice": 10.0}],
        "shippingAddress": "123 Valid Street",
    }
    event = make_apigw_event(method="POST", path="/orders", body=payload, user_id=None)

    response = lambda_handler(event, None)
    assert response["statusCode"] == 400
    body = json.loads(response["body"])
    assert body["error"] == "VALIDATION_ERROR"


def test_create_order_invalid_body(dynamodb_table):
    event = make_apigw_event(method="POST", path="/orders", body={"invalid": "payload"})

    response = lambda_handler(event, None)
    assert response["statusCode"] == 400
    body = json.loads(response["body"])
    assert body["error"] == "VALIDATION_ERROR"
