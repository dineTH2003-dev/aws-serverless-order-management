"""
Pydantic data models for the Order Management API.
Uses Decimal for precise financial calculations (eliminates IEEE-754 float rounding errors).
Supports idempotency keys, soft-deletion timestamps, and optimistic concurrency versioning.
"""

from __future__ import annotations

from datetime import UTC, datetime
from decimal import ROUND_HALF_UP, Decimal
from enum import Enum
from uuid import uuid4

from pydantic import BaseModel, Field, field_serializer, field_validator


class OrderStatus(str, Enum):
    PENDING = "PENDING"
    CONFIRMED = "CONFIRMED"
    SHIPPED = "SHIPPED"
    DELIVERED = "DELIVERED"
    CANCELLED = "CANCELLED"


class OrderItem(BaseModel):
    productId: str = Field(..., min_length=1, max_length=100)
    name: str = Field(..., min_length=1, max_length=200)
    quantity: int = Field(..., ge=1, le=1000)
    unitPrice: Decimal = Field(..., ge=Decimal("0.00"))

    @field_validator("unitPrice", mode="before")
    @classmethod
    def parse_unit_price(cls, v: float | int | str | Decimal) -> Decimal:
        return Decimal(str(v)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)

    @field_serializer("unitPrice", when_used="json")
    def serialize_unit_price(self, v: Decimal) -> float:
        return float(v)

    @property
    def subtotal(self) -> Decimal:
        return (Decimal(self.quantity) * self.unitPrice).quantize(
            Decimal("0.01"), rounding=ROUND_HALF_UP
        )


class CreateOrderRequest(BaseModel):
    items: list[OrderItem] = Field(..., min_length=1)
    shippingAddress: str = Field(..., min_length=5, max_length=500)
    notes: str | None = Field(None, max_length=1000)
    idempotencyKey: str | None = Field(None, max_length=128)

    @field_validator("items")
    @classmethod
    def items_not_empty(cls, v: list) -> list:
        if not v:
            raise ValueError("Order must contain at least one item")
        return v

    @property
    def total_amount(self) -> Decimal:
        return sum((item.subtotal for item in self.items), Decimal("0.00")).quantize(
            Decimal("0.01"), rounding=ROUND_HALF_UP
        )


class Order(BaseModel):
    """Full order domain model with optimistic concurrency and auditability."""

    orderId: str = Field(default_factory=lambda: str(uuid4()))
    userId: str
    status: OrderStatus = OrderStatus.PENDING
    items: list[OrderItem]
    totalAmount: Decimal
    shippingAddress: str
    notes: str | None = None
    idempotencyKey: str | None = None
    version: int = Field(default=1, ge=1)
    deletedAt: str | None = None
    createdAt: str = Field(default_factory=lambda: datetime.now(UTC).isoformat())
    updatedAt: str = Field(default_factory=lambda: datetime.now(UTC).isoformat())

    @field_validator("totalAmount", mode="before")
    @classmethod
    def parse_total_amount(cls, v: float | int | str | Decimal) -> Decimal:
        return Decimal(str(v)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)

    @field_serializer("totalAmount", when_used="json")
    def serialize_total_amount(self, v: Decimal) -> float:
        return float(v)

    def to_dynamodb_item(self) -> dict:
        """Convert the order to a DynamoDB-ready dict with Decimal numbers."""
        item: dict = {
            "PK": f"ORDER#{self.orderId}",
            "SK": "METADATA",
            "orderId": self.orderId,
            "userId": self.userId,
            "status": self.status.value,
            "items": [
                {
                    "productId": i.productId,
                    "name": i.name,
                    "quantity": i.quantity,
                    "unitPrice": i.unitPrice,
                }
                for i in self.items
            ],
            "totalAmount": self.totalAmount,
            "shippingAddress": self.shippingAddress,
            "notes": self.notes or "",
            "version": self.version,
            "createdAt": self.createdAt,
            "updatedAt": self.updatedAt,
        }
        if self.idempotencyKey:
            item["idempotencyKey"] = self.idempotencyKey
        if self.deletedAt:
            item["deletedAt"] = self.deletedAt
        return item

    @classmethod
    def from_dynamodb_item(cls, item: dict) -> Order:
        """Reconstruct an Order from a raw DynamoDB item dict."""
        return cls(
            orderId=item["orderId"],
            userId=item["userId"],
            status=OrderStatus(item["status"]),
            items=[
                OrderItem(
                    productId=i["productId"],
                    name=i["name"],
                    quantity=int(i["quantity"]),
                    unitPrice=Decimal(str(i["unitPrice"])),
                )
                for i in item["items"]
            ],
            totalAmount=Decimal(str(item["totalAmount"])),
            shippingAddress=item["shippingAddress"],
            notes=item.get("notes") or None,
            idempotencyKey=item.get("idempotencyKey") or None,
            version=int(item.get("version", 1)),
            deletedAt=item.get("deletedAt") or None,
            createdAt=item["createdAt"],
            updatedAt=item["updatedAt"],
        )
