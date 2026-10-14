"""
DynamoDB client abstraction layer.

Provides a clean interface for all DynamoDB operations used by
the order management Lambda functions. Centralises retry logic,
error mapping, and connection management (reuse across warm starts).
"""
from __future__ import annotations

import logging
import os
from typing import Any

import boto3
from boto3.dynamodb.conditions import Attr, Key
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)

# ── Module-level resource (reused across Lambda warm starts) ──────────────────
_dynamodb = boto3.resource("dynamodb", region_name=os.environ.get("AWS_REGION", "us-east-1"))
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

def put_item(item: dict) -> None:
    """Insert or fully replace an item. Raises on DynamoDB errors."""
    try:
        get_table().put_item(Item=item)
        logger.info("put_item success", extra={"pk": item.get("PK")})
    except ClientError as exc:
        logger.error("put_item failed", extra={"error": str(exc)})
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


def query_by_user(user_id: str, limit: int = 20, last_key: dict | None = None) -> dict:
    """
    Query all orders for a given userId using GSI-1 (userId-createdAt-index).
    Supports cursor-based pagination via last_key.
    """
    kwargs: dict = {
        "IndexName": "userId-createdAt-index",
        "KeyConditionExpression": Key("userId").eq(user_id),
        "Limit": limit,
        "ScanIndexForward": False,  # newest first
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
        logger.error("query_by_user failed", extra={"user_id": user_id, "error": str(exc)})
        raise


def query_by_status(status: str, limit: int = 20, last_key: dict | None = None) -> dict:
    """
    Query orders by status using GSI-2 (status-createdAt-index).
    """
    kwargs: dict = {
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


def delete_item(pk: str, sk: str = "METADATA") -> None:
    """
    Delete a single item by primary key.
    Uses a condition expression to ensure the item exists before deletion.
    Raises ClientError with ConditionalCheckFailedException if not found.
    """
    try:
        get_table().delete_item(
            Key={"PK": pk, "SK": sk},
            ConditionExpression=Attr("PK").exists(),
        )
        logger.info("delete_item success", extra={"pk": pk})
    except ClientError as exc:
        if exc.response["Error"]["Code"] == "ConditionalCheckFailedException":
            logger.warning("delete_item: item not found", extra={"pk": pk})
            return  # Treat as idempotent — already gone
        logger.error("delete_item failed", extra={"pk": pk, "error": str(exc)})
        raise
