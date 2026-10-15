"""
GET /orders/{orderId} — Retrieve a single order.

Fetches the order from DynamoDB, then enforces ownership:
only the user who created the order can retrieve it.
"""

from __future__ import annotations

from shared.db import get_item
from shared.exceptions import (
    ForbiddenError,
    NotFoundError,
    ValidationError,
    get_correlation_id,
    handle_exception,
    success_response,
)
from shared.logging import get_logger
from shared.models import Order

logger = get_logger(__name__)


def lambda_handler(event: dict, context) -> dict:
    correlation_id = get_correlation_id(event)
    try:
        # ── Extract authenticated user ─────────────────────────────────────────
        claims = event.get("requestContext", {}).get("authorizer", {}).get("claims", {})
        user_id = claims.get("sub")
        if not user_id:
            raise ValidationError("Unable to extract user identity from token claims")

        # ── Extract path parameter ─────────────────────────────────────────────
        order_id = (event.get("pathParameters") or {}).get("orderId")
        if not order_id:
            raise ValidationError("Missing required path parameter: orderId")

        # ── Fetch from DynamoDB ────────────────────────────────────────────────
        item = get_item(pk=f"ORDER#{order_id}")
        if item is None:
            raise NotFoundError(f"Order {order_id} not found")

        # ── Ownership check (prevents horizontal privilege escalation) ─────────
        if item.get("userId") != user_id:
            raise ForbiddenError("You do not have permission to access this order")

        order = Order.from_dynamodb_item(item)

        logger.info(
            "Order retrieved",
            extra={"order_id": order_id, "user_id": user_id, "correlation_id": correlation_id},
        )
        return success_response(order.model_dump(mode="json"), correlation_id=correlation_id)

    except Exception as exc:  # noqa: BLE001
        return handle_exception(exc, correlation_id)
