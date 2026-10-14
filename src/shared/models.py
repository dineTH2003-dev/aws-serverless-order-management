"""
Pydantic data models for the Order Management API.

These models handle input validation for all Lambda functions.
Pydantic v2 is used for performance and strict type safety.
"""
from __future__ import annotations

from datetime import datetime, timezone
from enum import Enum
from typing import Optional
from uuid import uuid4

from pydantic import BaseModel, Field, field_validator


class OrderStatus(str, Enum):
    PENDING   = "PENDING"
    CONFIRMED = "CONFIRMED"
    SHIPPED   = "SHIPPED"
    DELIVERED = "DELIVERED"
    CANCELLED = "CANCELLED"


class OrderItem(BaseModel):
    productId:  str   = Field(..., min_length=1, max_length=100)
    name:       str   = Field(..., min_length=1, max_length=200)
    quantity:   int   = Field(..., ge=1, le=1000)
    unitPrice:  float = Field(..., ge=0.0)

    @property
    def subtotal(self) -> float:
        return round(self.quantity * self.unitPrice, 2)


class CreateOrderRequest(BaseModel):
    items:           list[OrderItem] = Field(..., min_length=1)
    shippingAddress: str             = Field(..., min_length=5, max_length=500)
    notes:           Optional[str]   = Field(None, max_length=1000)

    @field_validator("items")
    @classmethod
    def items_not_empty(cls, v: list) -> list:
        if not v:
            raise ValueError("Order must contain at least one item")
        return v

    @property
    def total_amount(self) -> float:
        return round(sum(item.subtotal for item in self.items), 2)


class Order(BaseModel):
    """Full order domain model — used for serialisation into DynamoDB."""
    orderId:         str         = Field(default_factory=lambda: str(uuid4()))
    userId:          str
    status:          OrderStatus = OrderStatus.PENDING
    items:           list[OrderItem]
    totalAmount:     float
    shippingAddress: str
    notes:           Optional[str] = None
    createdAt:       str           = Field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )
    updatedAt:       str           = Field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )

    def to_dynamodb_item(self) -> dict:
        """Convert the order to a DynamoDB-ready dict."""
        return {
            "PK":              f"ORDER#{self.orderId}",
            "SK":              "METADATA",
            "orderId":         self.orderId,
            "userId":          self.userId,
            "status":          self.status.value,
            "items":           [item.model_dump() for item in self.items],
            "totalAmount":     str(self.totalAmount),   # Decimal-safe string
            "shippingAddress": self.shippingAddress,
            "notes":           self.notes or "",
            "createdAt":       self.createdAt,
            "updatedAt":       self.updatedAt,
        }

    @classmethod
    def from_dynamodb_item(cls, item: dict) -> "Order":
        """Reconstruct an Order from a raw DynamoDB item dict."""
        return cls(
            orderId=item["orderId"],
            userId=item["userId"],
            status=OrderStatus(item["status"]),
            items=[OrderItem(**i) for i in item["items"]],
            totalAmount=float(item["totalAmount"]),
            shippingAddress=item["shippingAddress"],
            notes=item.get("notes") or None,
            createdAt=item["createdAt"],
            updatedAt=item["updatedAt"],
        )
