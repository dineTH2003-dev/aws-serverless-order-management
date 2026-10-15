"""
GET /orders — List all orders for the authenticated user.

Queries DynamoDB GSI-1 (userId-createdAt-index) to return user orders, newest first.
Pushes status filtering down to DynamoDB (FilterExpression) to maintain pagination integrity.
Supports cursor-based pagination via lastKey query parameter.
"""

from __future__ import annotations

import json
import logging
import os

from shared.db import query_by_user
from shared.exceptions import (
    ValidationError,
    get_correlation_id,
    handle_exception,
    success_response,
)
from shared.models import Order, OrderStatus

logger = logging.getLogger(__name__)
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

_MAX_LIMIT = 100
_DEFAULT_LIMIT = 20


def lambda_handler(event: dict, context) -> dict:
    correlation_id = get_correlation_id(event)
    try:
        # ── Extract authenticated user ─────────────────────────────────────────
        claims = event.get("requestContext", {}).get("authorizer", {}).get("claims", {})
        user_id = claims.get("sub")
        if not user_id:
            raise ValidationError("Unable to extract user identity from token claims")

        # ── Extract query parameters ───────────────────────────────────────────
        params = event.get("queryStringParameters") or {}
        status_filter = params.get("status")
        last_key_raw = params.get("lastKey")

        try:
            limit = min(int(params.get("limit", _DEFAULT_LIMIT)), _MAX_LIMIT)
        except (ValueError, TypeError) as exc:
            raise ValidationError("Query parameter 'limit' must be an integer") from exc

        # Validate status filter if provided
        if status_filter and status_filter not in OrderStatus._value2member_map_:
            valid = ", ".join(OrderStatus._value2member_map_.keys())
            raise ValidationError(f"Invalid status '{status_filter}'. Must be one of: {valid}")

        # Decode pagination cursor
        last_key = json.loads(last_key_raw) if last_key_raw else None

        # ── Query DynamoDB with database-level status filtering ────────────────
        result = query_by_user(
            user_id=user_id,
            status=status_filter,
            limit=limit,
            last_key=last_key,
        )
        items = result["items"]

        orders = [Order.from_dynamodb_item(i).model_dump(mode="json") for i in items]

        response_body: dict = {"orders": orders, "count": len(orders)}
        if result.get("last_evaluated_key"):
            response_body["lastKey"] = json.dumps(result["last_evaluated_key"])

        logger.info(
            "Orders listed",
            extra={
                "user_id": user_id,
                "count": len(orders),
                "limit": limit,
                "correlation_id": correlation_id,
            },
        )
        return success_response(response_body, correlation_id=correlation_id)

    except Exception as exc:  # noqa: BLE001
        return handle_exception(exc, correlation_id)
