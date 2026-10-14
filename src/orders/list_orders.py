"""
GET /orders — List all orders for the authenticated user.

Queries DynamoDB GSI-1 (userId-createdAt-index) to return the user's
orders, newest first. Supports optional status filtering and cursor
pagination via the lastKey query parameter.
"""
from __future__ import annotations

import json
import logging
import os

from shared.db import query_by_user
from shared.exceptions import ValidationError, handle_exception, success_response
from shared.models import Order, OrderStatus

logger = logging.getLogger(__name__)
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

_MAX_LIMIT = 100
_DEFAULT_LIMIT = 20


def lambda_handler(event: dict, context) -> dict:
    try:
        # ── Extract authenticated user ─────────────────────────────────────────
        claims = event.get("requestContext", {}).get("authorizer", {}).get("claims", {})
        user_id = claims.get("sub")
        if not user_id:
            raise ValidationError("Unable to extract user identity from token claims")

        # ── Extract query parameters ───────────────────────────────────────────
        params = event.get("queryStringParameters") or {}
        status_filter = params.get("status")
        last_key_raw  = params.get("lastKey")

        try:
            limit = min(int(params.get("limit", _DEFAULT_LIMIT)), _MAX_LIMIT)
        except (ValueError, TypeError):
            raise ValidationError("Query parameter 'limit' must be an integer")

        # Validate status filter if provided
        if status_filter and status_filter not in OrderStatus._value2member_map_:
            valid = ", ".join(OrderStatus._value2member_map_.keys())
            raise ValidationError(f"Invalid status '{status_filter}'. Must be one of: {valid}")

        # Decode pagination cursor
        last_key = json.loads(last_key_raw) if last_key_raw else None

        # ── Query DynamoDB ─────────────────────────────────────────────────────
        result = query_by_user(user_id=user_id, limit=limit, last_key=last_key)
        items = result["items"]

        # Client-side status filter (no additional GSI query needed for now)
        if status_filter:
            items = [i for i in items if i.get("status") == status_filter]

        orders = [Order.from_dynamodb_item(i).model_dump() for i in items]

        response_body: dict = {"orders": orders, "count": len(orders)}
        if result.get("last_evaluated_key"):
            response_body["lastKey"] = json.dumps(result["last_evaluated_key"])

        logger.info(
            "Orders listed",
            extra={"user_id": user_id, "count": len(orders), "limit": limit},
        )
        return success_response(response_body)

    except Exception as exc:  # noqa: BLE001
        return handle_exception(exc)
