"""Pass-through sync orchestration for Genesys mock tables (Supabase → Fivetran)."""

from __future__ import annotations

import re
from datetime import date, datetime, timezone
from typing import Any, Optional

from fivetran_connector_sdk import Logging as log
from fivetran_connector_sdk import Operations as op

from entity_registry import (
    CHECKPOINT_INTERVAL,
    ENTITY_CONFIGS,
    EXPECTED_SCHEMA,
    PROGRESS_LOG_INTERVAL,
    EntityConfig,
)
from record_utils import to_passthrough_record
from supabase_client import SupabaseClient

_ISO_Z_PATTERN = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$")

STATE_ENTITY_INDEX = "entity_index"
EPOCH_START = "1970-01-01T00:00:00Z"
PK_CURSOR_START = ""


def validate_configuration(configuration: dict[str, Any]) -> None:
    """Ensure required Postgres connection settings and Genesys schema are present."""
    required = ("host", "database", "user", "password")
    for key in required:
        if not configuration.get(key):
            raise ValueError(f"Missing required configuration value: {key}")

    schema = configuration.get("schema", EXPECTED_SCHEMA)
    if schema != EXPECTED_SCHEMA:
        raise ValueError(
            f"Genesys connector must use schema={EXPECTED_SCHEMA!r}, got {schema!r}"
        )

    start_date = configuration.get("historical_sync_start_date")
    if start_date and not _ISO_Z_PATTERN.match(start_date):
        raise ValueError(
            f"Invalid historical_sync_start_date: {start_date}. "
            "Expected format: YYYY-MM-DDTHH:MM:SSZ"
        )


def _parse_timestamp(value: Any) -> Optional[datetime]:
    if value is None or value == "":
        return None
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    if isinstance(value, date) and not isinstance(value, datetime):
        return datetime(value.year, value.month, value.day, tzinfo=timezone.utc)
    text = str(value).strip()
    if not text:
        return None
    try:
        if text.endswith("Z"):
            text = text[:-1] + "+00:00"
        parsed = datetime.fromisoformat(text)
        return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)
    except ValueError:
        return None


def _format_timestamp(value: datetime) -> str:
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _get_cursor(
    state: dict[str, Any],
    table: str,
    config: EntityConfig,
    default_start: str,
) -> Any:
    # Full sync always re-reads the table; do not skip via prior cursors.
    if config.cursor_mode == "full":
        return PK_CURSOR_START

    cursors = state.get("cursors") or {}
    if table in cursors:
        return cursors[table]
    if config.cursor_mode == "primary_key":
        return PK_CURSOR_START
    return default_start


def _get_entity_index(state: dict[str, Any]) -> int:
    index = int(state.get(STATE_ENTITY_INDEX, 0))
    if index < 0 or index >= len(ENTITY_CONFIGS):
        return 0
    return index


def sync_entity(
    client: SupabaseClient,
    config: EntityConfig,
    state: dict[str, Any],
    default_start: str,
) -> tuple[dict[str, Any], int]:
    """Sync one table and upsert pass-through rows by primary key."""
    cursor_value = _get_cursor(state, config.table, config, default_start)
    log.info(
        f"Syncing {config.table} mode={config.cursor_mode} "
        f"pk={config.primary_key} cursor={cursor_value!r}"
    )

    max_seen_dt: Optional[datetime] = None
    if config.cursor_mode == "datetime":
        max_seen_dt = _parse_timestamp(cursor_value)
    max_seen_pk = str(cursor_value) if config.cursor_mode == "primary_key" else ""

    row_count = 0

    for record in client.query_table(
        config.table,
        config.cursor_field,
        cursor_value,
        cursor_mode=config.cursor_mode,
        primary_key=config.primary_key,
    ):
        pk_value = record.get(config.primary_key)
        if pk_value is None or pk_value == "":
            log.warning(
                f"Skipping {config.table} record without {config.primary_key}"
            )
            continue

        row = to_passthrough_record(record)
        op.upsert(table=config.table, data=row)
        row_count += 1

        if config.cursor_mode == "datetime":
            record_ts = _parse_timestamp(record.get(config.cursor_field))
            if record_ts and (max_seen_dt is None or record_ts > max_seen_dt):
                max_seen_dt = record_ts
            max_seen_pk = str(pk_value)
        elif config.cursor_mode == "primary_key":
            max_seen_pk = str(pk_value)

        if row_count % PROGRESS_LOG_INTERVAL == 0:
            log.info(f"{config.table}: {row_count} rows upserted so far...")

        # Mid-sync checkpoints for primary_key/datetime only. Full mode must not
        # persist a skip cursor across syncs (would miss later source edits).
        if (
            config.cursor_mode != "full"
            and row_count % CHECKPOINT_INTERVAL == 0
        ):
            interim_cursors = dict(state.get("cursors") or {})
            if config.cursor_mode == "datetime" and max_seen_dt:
                interim_cursors[config.table] = _format_timestamp(max_seen_dt)
            elif config.cursor_mode == "primary_key":
                interim_cursors[config.table] = max_seen_pk
            interim_state = {**state, "cursors": interim_cursors}
            op.checkpoint(interim_state)
            state = interim_state

    new_cursors = dict(state.get("cursors") or {})
    if config.cursor_mode == "full":
        # Drop any prior cursor so the next sync always re-reads.
        new_cursors.pop(config.table, None)
    elif config.cursor_mode == "datetime" and max_seen_dt and row_count > 0:
        new_cursors[config.table] = _format_timestamp(max_seen_dt)
    elif config.cursor_mode == "primary_key" and row_count > 0:
        new_cursors[config.table] = max_seen_pk
    elif config.table not in new_cursors and config.cursor_mode != "full":
        new_cursors[config.table] = str(cursor_value)

    updated_state = {**state, "cursors": new_cursors}
    log.info(f"Finished {config.table}: {row_count} rows upserted")
    return updated_state, row_count


def sync_all_entities(
    client: SupabaseClient,
    state: dict[str, Any],
    configuration: dict[str, Any],
) -> dict[str, Any]:
    """Sync every registered Genesys table in one update() call."""
    default_start = configuration.get("historical_sync_start_date") or EPOCH_START
    current_state = dict(state)
    total_rows = 0
    entity_index = _get_entity_index(current_state)

    while entity_index < len(ENTITY_CONFIGS):
        config = ENTITY_CONFIGS[entity_index]
        log.info(
            f"Processing entity {entity_index + 1}/{len(ENTITY_CONFIGS)}: {config.table}"
        )

        current_state, row_count = sync_entity(
            client,
            config,
            current_state,
            default_start,
        )

        total_rows += row_count
        entity_index += 1
        current_state = {**current_state, STATE_ENTITY_INDEX: entity_index}
        op.checkpoint(current_state)

    current_state = {**current_state, STATE_ENTITY_INDEX: 0}
    op.checkpoint(current_state)
    log.info(f"Sync complete: {total_rows} total rows upserted across all entities")
    return current_state
