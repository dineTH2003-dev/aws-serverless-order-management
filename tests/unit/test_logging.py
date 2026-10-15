import json
import logging

from shared.logging import JsonFormatter, get_logger


def test_json_formatter_serializes_extra_fields():
    formatter = JsonFormatter()
    record = logging.LogRecord(
        name="test_logger",
        level=logging.INFO,
        pathname="test.py",
        lineno=10,
        msg="Test message",
        args=(),
        exc_info=None,
    )
    record.order_id = "test-order-123"
    record.correlation_id = "test-cid-456"

    output = formatter.format(record)
    data = json.loads(output)

    assert data["message"] == "Test message"
    assert data["level"] == "INFO"
    assert data["order_id"] == "test-order-123"
    assert data["correlation_id"] == "test-cid-456"
    assert "timestamp" in data


def test_get_logger_singleton():
    logger1 = get_logger("custom.service")
    logger2 = get_logger("custom.service")
    assert logger1 is logger2
    assert len(logger1.handlers) == 1
