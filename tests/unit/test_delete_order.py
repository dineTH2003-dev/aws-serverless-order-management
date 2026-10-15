import json

from helpers import make_apigw_event

from orders.delete_order import lambda_handler
from shared.db import get_item, put_item
from shared.models import Order, OrderItem


def test_delete_order_success(dynamodb_table):
    order = Order(
        userId="user-owner",
        items=[OrderItem(productId="p1", name="Product", quantity=1, unitPrice=25.0)],
        totalAmount=25.0,
        shippingAddress="123 Owner Street",
    )
    put_item(order.to_dynamodb_item())

    event = make_apigw_event(
        method="DELETE",
        path=f"/orders/{order.orderId}",
        path_params={"orderId": order.orderId},
        user_id="user-owner",
    )
    response = lambda_handler(event, None)
    assert response["statusCode"] == 204

    # Verify item was soft-deleted in DynamoDB (status=CANCELLED, deletedAt set)
    item = get_item(pk=f"ORDER#{order.orderId}")
    assert item is not None
    assert item["status"] == "CANCELLED"
    assert item.get("deletedAt") is not None


def test_delete_order_idempotent_for_already_cancelled(dynamodb_table):
    order = Order(
        userId="user-owner",
        items=[OrderItem(productId="p1", name="Product", quantity=1, unitPrice=25.0)],
        totalAmount=25.0,
        shippingAddress="123 Owner Street",
    )
    put_item(order.to_dynamodb_item())

    event = make_apigw_event(
        method="DELETE",
        path=f"/orders/{order.orderId}",
        path_params={"orderId": order.orderId},
        user_id="user-owner",
    )
    res1 = lambda_handler(event, None)
    assert res1["statusCode"] == 204

    # Second delete returns 204 idempotently
    res2 = lambda_handler(event, None)
    assert res2["statusCode"] == 204


def test_delete_order_forbidden_for_other_user(dynamodb_table):
    order = Order(
        userId="user-owner",
        items=[OrderItem(productId="p1", name="Product", quantity=1, unitPrice=25.0)],
        totalAmount=25.0,
        shippingAddress="123 Owner Street",
    )
    put_item(order.to_dynamodb_item())

    event = make_apigw_event(
        method="DELETE",
        path=f"/orders/{order.orderId}",
        path_params={"orderId": order.orderId},
        user_id="user-attacker",
    )
    response = lambda_handler(event, None)
    assert response["statusCode"] == 403
    body = json.loads(response["body"])
    assert body["error"] == "FORBIDDEN"

    # Item should still exist and not be cancelled
    item = get_item(pk=f"ORDER#{order.orderId}")
    assert item is not None
    assert item["status"] == "PENDING"


def test_delete_order_not_found(dynamodb_table):
    event = make_apigw_event(
        method="DELETE",
        path="/orders/non-existent-order",
        path_params={"orderId": "non-existent-order"},
        user_id="user-owner",
    )
    response = lambda_handler(event, None)
    assert response["statusCode"] == 404
    body = json.loads(response["body"])
    assert body["error"] == "NOT_FOUND"
