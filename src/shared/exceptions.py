"""
Custom exception types and HTTP response helpers with correlation IDs and strict CORS.
"""

from __future__ import annotations

import json
import os
from uuid import uuid4

from shared.logging import get_logger

logger = get_logger(__name__)


# ── Domain Exceptions ─────────────────────────────────────────────────────────


class OrderManagementError(Exception):
    """Base class for all domain exceptions."""

    status_code: int = 500
    error_code: str = "INTERNAL_ERROR"

    def __init__(self, message: str) -> None:
        super().__init__(message)
        self.message = message


class ValidationError(OrderManagementError):
    status_code = 400
    error_code = "VALIDATION_ERROR"


class NotFoundError(OrderManagementError):
    status_code = 404
    error_code = "NOT_FOUND"


class ForbiddenError(OrderManagementError):
    status_code = 403
    error_code = "FORBIDDEN"


class ConflictError(OrderManagementError):
    status_code = 409
    error_code = "CONFLICT"


# ── Response builders ─────────────────────────────────────────────────────────


def get_correlation_id(event: dict | None = None) -> str:
    """Extract or generate a distributed trace correlation ID."""
    if event:
        headers = event.get("headers") or {}
        cid = headers.get("x-correlation-id") or headers.get("X-Correlation-Id")
        if cid:
            return cid
    return str(uuid4())


def _cors_headers(correlation_id: str | None = None) -> dict[str, str]:
    headers = {
        "Access-Control-Allow-Origin": os.environ.get("ALLOWED_ORIGIN", "*"),
        "Access-Control-Allow-Headers": "Authorization,Content-Type,Idempotency-Key,X-Correlation-Id",
        "Access-Control-Allow-Methods": "GET,POST,DELETE,OPTIONS",
        "Content-Type": "application/json",
    }
    if correlation_id:
        headers["X-Correlation-Id"] = correlation_id
    return headers


def success_response(
    body: dict | list, status_code: int = 200, correlation_id: str | None = None
) -> dict:
    """Return a successful API Gateway proxy response."""
    return {
        "statusCode": status_code,
        "headers": _cors_headers(correlation_id),
        "body": json.dumps(body, default=str),
    }


def error_response(
    error_code: str,
    message: str,
    status_code: int = 500,
    correlation_id: str | None = None,
) -> dict:
    """Return an error API Gateway proxy response with correlation tracking."""
    logger.error(
        "error_response",
        extra={"error_code": error_code, "err_detail": message, "correlation_id": correlation_id},
    )
    return {
        "statusCode": status_code,
        "headers": _cors_headers(correlation_id),
        "body": json.dumps(
            {
                "error": error_code,
                "message": message,
                "correlationId": correlation_id or "",
            }
        ),
    }


def handle_exception(exc: Exception, correlation_id: str | None = None) -> dict:
    """Convert any domain or runtime exception to the appropriate HTTP response."""
    if isinstance(exc, OrderManagementError):
        return error_response(exc.error_code, exc.message, exc.status_code, correlation_id)
    logger.exception("Unhandled exception", extra={"correlation_id": correlation_id})
    return error_response("INTERNAL_ERROR", "An unexpected error occurred.", 500, correlation_id)
