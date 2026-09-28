"""CCB entity definitions for the Fivetran connector.

Reads only from Supabase schema ``ccb_mock``. Sync order follows the synthetic
data load order (dimensions before facts). POC tables lack reliable
``updated_at`` change-tracking, so every table uses full-table upsert by PK.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Literal

MAX_RECORDS_PER_PAGE = 500
PROGRESS_LOG_INTERVAL = 100
CHECKPOINT_INTERVAL = 500

# full: re-read entire table each sync; upserts by primary_key are idempotent.
# primary_key / datetime kept for future use if reliable cursors appear.
CursorMode = Literal["full", "primary_key", "datetime"]

EXPECTED_SCHEMA = "ccb_mock"


@dataclass(frozen=True)
class EntityConfig:
    """Configuration for syncing one Postgres table into a Fivetran destination table."""

    table: str
    primary_key: str
    cursor_mode: CursorMode = "full"
    # Physical column used for ordering / incremental reads when not full.
    cursor_field: str = ""

    def __post_init__(self) -> None:
        if not self.cursor_field:
            object.__setattr__(self, "cursor_field", self.primary_key)


ENTITY_CONFIGS: list[EntityConfig] = [
    EntityConfig("persons", "person_id"),
    EntityConfig("accounts", "account_id"),
    EntityConfig("account_persons", "account_person_id"),
    EntityConfig("premises", "premise_id"),
    EntityConfig("service_points", "service_point_id"),
    EntityConfig("meters", "meter_id"),
    EntityConfig("bills", "bill_id"),
    EntityConfig("payments", "payment_id"),
    EntityConfig("consumption", "consumption_id"),
    EntityConfig("contact_notes", "contact_note_id"),
    EntityConfig("field_activities", "field_activity_id"),
    EntityConfig("service_history", "service_history_id"),
    EntityConfig("lead_program", "lead_program_id"),
]

ENTITY_TABLES = [config.table for config in ENTITY_CONFIGS]

ENTITY_BY_TABLE = {config.table: config for config in ENTITY_CONFIGS}
