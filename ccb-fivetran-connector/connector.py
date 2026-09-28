"""
Fivetran Connector SDK connector for Denver Water CCB synthetic data in Supabase.

Reads Postgres tables from schema ``ccb_mock`` and upserts rows with source
column names unchanged (no transformations or Autotask shaping).

Deploy as Fivetran connection: ``denver_ccb``
"""

from __future__ import annotations

import json
from typing import Any

from fivetran_connector_sdk import Connector
from fivetran_connector_sdk import Logging as log

from entity_registry import ENTITY_CONFIGS, EXPECTED_SCHEMA
from supabase_client import SupabaseClient
from sync_entities import sync_all_entities, validate_configuration


def schema(configuration: dict[str, Any]) -> list[dict[str, Any]]:
    """Define destination tables and their actual text primary keys."""
    return [
        {"table": config.table, "primary_key": [config.primary_key]}
        for config in ENTITY_CONFIGS
    ]


def update(configuration: dict[str, Any], state: dict[str, Any]) -> None:
    """Fetch CCB mock rows and upsert pass-through records."""
    log.warning("Denver Water CCB Connector: starting sync")

    validate_configuration(configuration)

    client = SupabaseClient(
        host=configuration["host"],
        database=configuration["database"],
        user=configuration["user"],
        password=configuration["password"],
        port=configuration.get("port", "5432"),
        schema=configuration.get("schema", EXPECTED_SCHEMA),
        sslmode=configuration.get("sslmode", "require"),
    )

    try:
        sync_all_entities(client, state, configuration)
    except Exception as exc:
        raise RuntimeError(f"CCB sync failed: {exc}") from exc
    finally:
        client.close()


connector = Connector(update=update, schema=schema)

if __name__ == "__main__":
    with open("configuration.json", "r", encoding="utf-8") as config_file:
        local_configuration = json.load(config_file)
    connector.debug(configuration=local_configuration)
