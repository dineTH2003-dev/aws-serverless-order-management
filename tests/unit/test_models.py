import pytest
from pydantic import ValidationError
from shared.models import CreateOrderRequest, Order, OrderItem, OrderStatus


def test_order_item_subtotal():
    item = OrderItem(productId="prod-1", name="Keyboard", quantity=2, unitPrice=50.0)
    assert item.subtotal == 100.0


def test_create_order_request_validation():
    req = CreateOrderRequest(
        items=[
            OrderItem(productId="p1", name="Item 1", quantity=2, unitPrice=25.0),
            OrderItem(productId="p2", name="Item 2", quantity=1, unitPrice=15.5),
        ],
        shippingAddress="123 Test Street, Colombo",
    )
    assert req.total_amount == 65.5


def test_create_order_request_empty_items_fails():
    with pytest.raises(ValidationError):
        CreateOrderRequest(items=[], shippingAddress="123 Valid St")


def test_create_order_request_invalid_address():
    with pytest.raises(ValidationError):
        CreateOrderRequest(
            items=[OrderItem(productId="p1", name="Item 1", quantity=1, unitPrice=10.0)],
            shippingAddress="ab",  # min_length is 5
        )


def test_order_dynamodb_roundtrip():
    order = Order(
        userId="user-123",
        items=[OrderItem(productId="p1", name="Item 1", quantity=3, unitPrice=10.0)],
        totalAmount=30.0,
        shippingAddress="123 Test Street, Colombo",
        notes="Urgent delivery",
    )
    item = order.to_dynamodb_item()
    assert item["PK"] == f"ORDER#{order.orderId}"
    assert item["SK"] == "METADATA"
    assert item["status"] == "PENDING"
    from decimal import Decimal
    assert item["totalAmount"] == Decimal("30.0")

    reconstructed = Order.from_dynamodb_item(item)
    assert reconstructed.orderId == order.orderId
    assert reconstructed.userId == "user-123"
    assert reconstructed.status == OrderStatus.PENDING
    assert len(reconstructed.items) == 1
    assert reconstructed.items[0].subtotal == 30.0
    assert reconstructed.notes == "Urgent delivery"
