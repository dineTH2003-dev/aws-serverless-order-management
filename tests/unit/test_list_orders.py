import json
from helpers import make_apigw_event
from orders.list_orders import lambda_handler
from shared.db import put_item
from shared.models import Order, OrderItem, OrderStatus


def test_list_orders_for_user(dynamodb_table):
    # Insert 2 orders for user-1, 1 for user-2
    for i in range(2):
        o = Order(
            userId="user-1",
            items=[OrderItem(productId=f"p{i}", name=f"Item {i}", quantity=1, unitPrice=10.0)],
            totalAmount=10.0,
            shippingAddress="123 User1 Way",
        )
        put_item(o.to_dynamodb_item())

    other = Order(
        userId="user-2",
        items=[OrderItem(productId="px", name="Item X", quantity=1, unitPrice=5.0)],
        totalAmount=5.0,
        shippingAddress="456 User2 Rd",
    )
    put_item(other.to_dynamodb_item())

    event = make_apigw_event(method="GET", path="/orders", user_id="user-1")
    response = lambda_handler(event, None)
    assert response["statusCode"] == 200
    body = json.loads(response["body"])
    assert body["count"] == 2
    for order in body["orders"]:
        assert order["userId"] == "user-1"


def test_list_orders_status_filter(dynamodb_table):
    o1 = Order(
        userId="user-filter",
        status=OrderStatus.PENDING,
        items=[OrderItem(productId="p1", name="Item 1", quantity=1, unitPrice=10.0)],
        totalAmount=10.0,
        shippingAddress="Address 1",
    )
    o2 = Order(
        userId="user-filter",
        status=OrderStatus.SHIPPED,
        items=[OrderItem(productId="p2", name="Item 2", quantity=1, unitPrice=20.0)],
        totalAmount=20.0,
        shippingAddress="Address 2",
    )
    put_item(o1.to_dynamodb_item())
    put_item(o2.to_dynamodb_item())

    event = make_apigw_event(
        method="GET",
        path="/orders",
        query_params={"status": "PENDING"},
        user_id="user-filter",
    )
    response = lambda_handler(event, None)
    assert response["statusCode"] == 200
    body = json.loads(response["body"])
    assert body["count"] == 1
    assert body["orders"][0]["status"] == "PENDING"
