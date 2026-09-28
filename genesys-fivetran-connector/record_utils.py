"""Serialize Postgres rows for Fivetran upsert without reshaping columns."""

from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal
from typing import Any


def to_jsonable(value: Any) -> Any:
    """Convert common Postgres types to JSON-serializable values."""
    if value is None:
        return None
    if isinstance(value, datetime):
        if value.tzinfo is None:
            return value.strftime("%Y-%m-%dT%H:%M:%SZ")
        return value.astimezone().strftime("%Y-%m-%dT%H:%M:%SZ")
    if isinstance(value, date):
        return value.isoformat()
    if isinstance(value, Decimal):
        return float(value)
    if isinstance(value, memoryview):
        return bytes(value).decode("utf-8", errors="replace")
    if isinstance(value, bytes):
        return value.decode("utf-8", errors="replace")
    return value


def to_passthrough_record(row: dict[str, Any]) -> dict[str, Any]:
    """Return the source row with values made JSON-safe; column names unchanged."""
    return {key: to_jsonable(value) for key, value in row.items()}
