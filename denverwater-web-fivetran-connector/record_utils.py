"""Serialize scraped page records for Fivetran upsert."""

from __future__ import annotations

from datetime import date, datetime
from typing import Any


def to_jsonable(value: Any) -> Any:
    """Convert common Python types to JSON-serializable values."""
    if value is None:
        return None
    if isinstance(value, datetime):
        if value.tzinfo is None:
            return value.strftime("%Y-%m-%dT%H:%M:%SZ")
        return value.astimezone().strftime("%Y-%m-%dT%H:%M:%SZ")
    if isinstance(value, date):
        return value.isoformat()
    return value


def to_page_record(row: dict[str, Any]) -> dict[str, Any]:
    """Return a page row with values made JSON-safe; column names unchanged."""
    return {key: to_jsonable(value) for key, value in row.items()}
