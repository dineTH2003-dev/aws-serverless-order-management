"""
Custom exception types and HTTP response helpers.
"""
from __future__ import annotations

import json
import logging
import os

logger = logging.getLogger(__name__)


# ── Base exception ────────────────────────────────────────────────────────────

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


# ── Response builders ─────────────────────────────────────────────────────────

def _cors_headers() -> dict:
    return {
        "Access-Control-Allow-Origin": os.environ.get("ALLOWED_ORIGIN", "*"),
        "Access-Control-Allow-Headers": "Authorization,Content-Type",
        "Access-Control-Allow-Methods": "GET,POST,DELETE,OPTIONS",
        "Content-Type": "application/json",
    }


def success_response(body: dict | list, status_code: int = 200) -> dict:
    """Return a successful API Gateway proxy response."""
    return {
        "statusCode": status_code,
        "headers": _cors_headers(),
        "body": json.dumps(body, default=str),
    }


def error_response(error_code: str, message: str, status_code: int = 500) -> dict:
    """Return an error API Gateway proxy response."""
    logger.error("error_response", extra={"error_code": error_code, "err_detail": message})
    return {
        "statusCode": status_code,
        "headers": _cors_headers(),
        "body": json.dumps({"error": error_code, "message": message}),
    }


def handle_exception(exc: Exception) -> dict:
    """Convert any exception to the appropriate HTTP response."""
    if isinstance(exc, OrderManagementError):
        return error_response(exc.error_code, exc.message, exc.status_code)
    logger.exception("Unhandled exception")
    return error_response("INTERNAL_ERROR", "An unexpected error occurred.", 500)
