import json
from helpers import make_apigw_event
from orders.get_order import lambda_handler
from shared.db import put_item
from shared.models import Order, OrderItem


def test_get_order_success(dynamodb_table):
    order = Order(
        userId="user-owner",
        items=[OrderItem(productId="p1", name="Product", quantity=1, unitPrice=20.0)],
        totalAmount=20.0,
        shippingAddress="123 Owner Street",
    )
    put_item(order.to_dynamodb_item())

    event = make_apigw_event(
        method="GET",
        path=f"/orders/{order.orderId}",
        path_params={"orderId": order.orderId},
        user_id="user-owner",
    )
    response = lambda_handler(event, None)
    assert response["statusCode"] == 200
    body = json.loads(response["body"])
    assert body["orderId"] == order.orderId
    assert body["userId"] == "user-owner"


def test_get_order_forbidden_for_different_user(dynamodb_table):
    order = Order(
        userId="user-owner",
        items=[OrderItem(productId="p1", name="Product", quantity=1, unitPrice=20.0)],
        totalAmount=20.0,
        shippingAddress="123 Owner Street",
    )
    put_item(order.to_dynamodb_item())

    event = make_apigw_event(
        method="GET",
        path=f"/orders/{order.orderId}",
        path_params={"orderId": order.orderId},
        user_id="user-attacker",
    )
    response = lambda_handler(event, None)
    assert response["statusCode"] == 403
    body = json.loads(response["body"])
    assert body["error"] == "FORBIDDEN"


def test_get_order_not_found(dynamodb_table):
    event = make_apigw_event(
        method="GET",
        path="/orders/non-existent-id",
        path_params={"orderId": "non-existent-id"},
        user_id="user-owner",
    )
    response = lambda_handler(event, None)
    assert response["statusCode"] == 404
    body = json.loads(response["body"])
    assert body["error"] == "NOT_FOUND"
