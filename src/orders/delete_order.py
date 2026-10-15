"""
DELETE /orders/{orderId} — Soft-delete an order.

Performs an atomic single-round-trip soft-deletion (status = CANCELLED, deletedAt = now).
Preserves legal and financial transaction history while enforcing tenant isolation.
"""

from __future__ import annotations

import logging
import os

from botocore.exceptions import ClientError

from shared.db import get_item, soft_delete_order
from shared.exceptions import (
    ForbiddenError,
    NotFoundError,
    ValidationError,
    _cors_headers,
    get_correlation_id,
    handle_exception,
)

logger = logging.getLogger(__name__)
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))


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

        # ── Atomic soft-deletion in a single round trip ────────────────────────
        try:
            soft_delete_order(order_id=order_id, user_id=user_id)
        except ClientError as exc:
            if exc.response["Error"]["Code"] == "ConditionalCheckFailedException":
                # Diagnose reason for condition failure
                item = get_item(pk=f"ORDER#{order_id}")
                if item is None:
                    raise NotFoundError(f"Order {order_id} not found") from exc
                if item.get("userId") != user_id:
                    raise ForbiddenError("You do not have permission to delete this order") from exc
                if item.get("status") == "CANCELLED":
                    # Idempotent repeat delete of already cancelled order
                    return {
                        "statusCode": 204,
                        "headers": _cors_headers(correlation_id),
                        "body": "",
                    }
            raise

        logger.info(
            "Order soft-deleted",
            extra={"order_id": order_id, "user_id": user_id, "correlation_id": correlation_id},
        )

        return {
            "statusCode": 204,
            "headers": _cors_headers(correlation_id),
            "body": "",
        }

    except Exception as exc:  # noqa: BLE001
        return handle_exception(exc, correlation_id)
