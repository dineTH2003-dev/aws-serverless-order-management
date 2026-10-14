"""
POST /orders — Create a new order.

Extracts the authenticated userId from the Cognito JWT claims injected
by API Gateway, validates the request body, persists to DynamoDB, and
returns the created order with HTTP 201.
"""
from __future__ import annotations

import json
import logging
import os

from pydantic import ValidationError as PydanticValidationError

from shared.db import put_item
from shared.exceptions import ValidationError, handle_exception, success_response
from shared.models import CreateOrderRequest, Order

logger = logging.getLogger(__name__)
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))


def lambda_handler(event: dict, context) -> dict:
    try:
        # ── Extract authenticated user from Cognito JWT claims ────────────────
        claims = event.get("requestContext", {}).get("authorizer", {}).get("claims", {})
        user_id = claims.get("sub")
        if not user_id:
            raise ValidationError("Unable to extract user identity from token claims")

        # ── Parse and validate request body ───────────────────────────────────
        body = event.get("body") or "{}"
        if isinstance(body, str):
            body = json.loads(body)

        try:
            request = CreateOrderRequest.model_validate(body)
        except PydanticValidationError as exc:
            raise ValidationError(f"Invalid request body: {exc.errors()[0]['msg']}") from exc

        # ── Build domain object ───────────────────────────────────────────────
        order = Order(
            userId=user_id,
            items=request.items,
            totalAmount=request.total_amount,
            shippingAddress=request.shippingAddress,
            notes=request.notes,
        )

        # ── Persist to DynamoDB ───────────────────────────────────────────────
        put_item(order.to_dynamodb_item())

        logger.info(
            "Order created",
            extra={"order_id": order.orderId, "user_id": user_id, "total": order.totalAmount},
        )

        return success_response(order.model_dump(), status_code=201)

    except Exception as exc:  # noqa: BLE001
        return handle_exception(exc)
