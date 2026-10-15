"""
DynamoDB client abstraction layer.

Provides a clean, enterprise-grade interface for all DynamoDB operations.
Configures resilient Boto3 retries, socket timeouts, atomic conditional mutations,
and soft-deletion workflows.
"""

from __future__ import annotations

import os
from datetime import UTC, datetime
from typing import Any

import boto3
from boto3.dynamodb.conditions import Attr, Key
from botocore.config import Config
from botocore.exceptions import ClientError

from shared.logging import get_logger

logger = get_logger(__name__)

# ── Module-level resource with production connection tuning ───────────────────
_boto_config = Config(
    retries={"max_attempts": 3, "mode": "standard"},
    connect_timeout=2,
    read_timeout=3,
    tcp_keepalive=True,
)

_dynamodb = boto3.resource(
    "dynamodb",
    region_name=os.environ.get("AWS_REGION", "us-east-1"),
    config=_boto_config,
)
_table: Any = None


def get_table() -> Any:
    """Return the DynamoDB Table resource, creating it once per Lambda container."""
    global _table
    if _table is None:
        table_name = os.environ["TABLE_NAME"]
        _table = _dynamodb.Table(table_name)
        logger.info("DynamoDB table initialised", extra={"table_name": table_name})
    return _table


# ── CRUD helpers ──────────────────────────────────────────────────────────────


def put_item(item: dict, condition_expression: Any = None) -> None:
    """Insert or conditionally put an item into DynamoDB."""
    kwargs: dict[str, Any] = {"Item": item}
    if condition_expression is not None:
        kwargs["ConditionExpression"] = condition_expression

    try:
        get_table().put_item(**kwargs)
        logger.info("put_item success", extra={"pk": item.get("PK")})
    except ClientError as exc:
        logger.error("put_item failed", extra={"error": str(exc), "pk": item.get("PK")})
        raise


def get_item(pk: str, sk: str = "METADATA") -> dict | None:
    """
    Fetch a single item by primary key.
    Returns None if the item does not exist.
    """
    try:
        response = get_table().get_item(Key={"PK": pk, "SK": sk})
        return response.get("Item")
    except ClientError as exc:
        logger.error("get_item failed", extra={"pk": pk, "error": str(exc)})
        raise


def query_by_user(
    user_id: str,
    status: str | None = None,
    limit: int = 20,
    last_key: dict | None = None,
) -> dict:
    """
    Query orders for a given userId using GSI-1 (userId-createdAt-index).
    Supports database-level status filtering and cursor-based pagination.
    """
    kwargs: dict[str, Any] = {
        "IndexName": "userId-createdAt-index",
        "KeyConditionExpression": Key("userId").eq(user_id),
        "Limit": limit,
        "ScanIndexForward": False,  # newest first
    }
    if status:
        kwargs["FilterExpression"] = Attr("status").eq(status)
    if last_key:
        kwargs["ExclusiveStartKey"] = last_key

    try:
        response = get_table().query(**kwargs)
        return {
            "items": response.get("Items", []),
            "last_evaluated_key": response.get("LastEvaluatedKey"),
            "count": response.get("Count", 0),
        }
    except ClientError as exc:
        logger.error("query_by_user failed", extra={"user_id": user_id, "error": str(exc)})
        raise


def query_by_status(status: str, limit: int = 20, last_key: dict | None = None) -> dict:
    """
    Query orders by status using GSI-2 (status-createdAt-index).
    """
    kwargs: dict[str, Any] = {
        "IndexName": "status-createdAt-index",
        "KeyConditionExpression": Key("status").eq(status),
        "Limit": limit,
        "ScanIndexForward": False,
    }
    if last_key:
        kwargs["ExclusiveStartKey"] = last_key

    try:
        response = get_table().query(**kwargs)
        return {
            "items": response.get("Items", []),
            "last_evaluated_key": response.get("LastEvaluatedKey"),
            "count": response.get("Count", 0),
        }
    except ClientError as exc:
        logger.error("query_by_status failed", extra={"status": status, "error": str(exc)})
        raise


def soft_delete_order(order_id: str, user_id: str) -> dict:
    """
    Atomically soft-delete an order in a single DynamoDB round trip.
    Sets status = CANCELLED and records deletedAt timestamp.
    Raises ConditionalCheckFailedException if the order doesn't exist,
    belongs to another user, or is already cancelled.
    """
    now = datetime.now(UTC).isoformat()
    try:
        response = get_table().update_item(
            Key={"PK": f"ORDER#{order_id}", "SK": "METADATA"},
            UpdateExpression="SET #status = :cancelled, deletedAt = :now, updatedAt = :now",
            ConditionExpression="attribute_exists(PK) AND userId = :user_id AND #status <> :cancelled",
            ExpressionAttributeNames={"#status": "status"},
            ExpressionAttributeValues={
                ":cancelled": "CANCELLED",
                ":user_id": user_id,
                ":now": now,
            },
            ReturnValues="ALL_NEW",
        )
        logger.info("soft_delete_order success", extra={"order_id": order_id, "user_id": user_id})
        return response.get("Attributes", {})
    except ClientError as exc:
        logger.warning(
            "soft_delete_order condition failed or error",
            extra={"order_id": order_id, "error": str(exc)},
        )
        raise


def delete_item(pk: str, sk: str = "METADATA") -> None:
    """Hard-delete item (maintained for test fixture cleanup)."""
    try:
        get_table().delete_item(
            Key={"PK": pk, "SK": sk},
            ConditionExpression=Attr("PK").exists(),
        )
    except ClientError as exc:
        if exc.response["Error"]["Code"] == "ConditionalCheckFailedException":
            return
        raise
