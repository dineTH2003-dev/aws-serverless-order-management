"""
POST /orders — Create a new order.

Extracts authenticated userId from Cognito JWT claims, enforces idempotency,
validates payload with Pydantic, performs Decimal calculations, and persists to DynamoDB.
"""

from __future__ import annotations

import json
import logging
import os

from botocore.exceptions import ClientError
from pydantic import ValidationError as PydanticValidationError

from shared.db import put_item
from shared.exceptions import (
    ConflictError,
    ValidationError,
    get_correlation_id,
    handle_exception,
    success_response,
)
from shared.models import CreateOrderRequest, Order

logger = logging.getLogger(__name__)
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))


def lambda_handler(event: dict, context) -> dict:
    correlation_id = get_correlation_id(event)
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

        # Check for Idempotency-Key header if not in payload
        headers = event.get("headers") or {}
        idempotency_header = headers.get("Idempotency-Key") or headers.get("idempotency-key")
        if idempotency_header and not body.get("idempotencyKey"):
            body["idempotencyKey"] = idempotency_header

        try:
            request = CreateOrderRequest.model_validate(body)
        except PydanticValidationError as exc:
            raise ValidationError(f"Invalid request body: {exc.errors()[0]['msg']}") from exc

        # ── Build domain object with Decimal precision ────────────────────────
        order_kwargs = {
            "userId": user_id,
            "items": request.items,
            "totalAmount": request.total_amount,
            "shippingAddress": request.shippingAddress,
            "notes": request.notes,
        }
        if request.idempotencyKey:
            order_kwargs["idempotencyKey"] = request.idempotencyKey

        order = Order(**order_kwargs)

        # ── Persist to DynamoDB with condition check ──────────────────────────
        try:
            put_item(order.to_dynamodb_item(), condition_expression="attribute_not_exists(PK)")
        except ClientError as exc:
            if exc.response["Error"]["Code"] == "ConditionalCheckFailedException":
                raise ConflictError(
                    "An order with this ID or idempotency key already exists"
                ) from exc
            raise

        logger.info(
            "Order created successfully",
            extra={
                "order_id": order.orderId,
                "user_id": user_id,
                "total": str(order.totalAmount),
                "correlation_id": correlation_id,
            },
        )

        return success_response(
            order.model_dump(mode="json"), status_code=201, correlation_id=correlation_id
        )

    except Exception as exc:  # noqa: BLE001
        return handle_exception(exc, correlation_id)
