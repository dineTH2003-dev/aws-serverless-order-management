"""
DELETE /orders/{orderId} — Delete an order.

Fetches the order first to verify it exists and that the requesting
user is the owner. Then hard-deletes the item from DynamoDB.
"""
from __future__ import annotations

import logging
import os

from shared.db import delete_item, get_item
from shared.exceptions import ForbiddenError, NotFoundError, ValidationError, handle_exception, success_response

logger = logging.getLogger(__name__)
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))


def lambda_handler(event: dict, context) -> dict:
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

        # ── Fetch order to verify ownership before deletion ────────────────────
        item = get_item(pk=f"ORDER#{order_id}")
        if item is None:
            raise NotFoundError(f"Order {order_id} not found")

        if item.get("userId") != user_id:
            raise ForbiddenError("You do not have permission to delete this order")

        # ── Delete from DynamoDB ───────────────────────────────────────────────
        delete_item(pk=f"ORDER#{order_id}")

        logger.info("Order deleted", extra={"order_id": order_id, "user_id": user_id})

        # HTTP 204 No Content — no body
        return {
            "statusCode": 204,
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "DELETE,OPTIONS",
            },
            "body": "",
        }

    except Exception as exc:  # noqa: BLE001
        return handle_exception(exc)
