"""
Fivetran Connector SDK connector for DenverWater.org public Customer Care pages.

Scrapes a controlled set of public pages (no full-site crawl) and upserts cleaned
page records into ``denverwater_pages`` for later dbt / RAG use.

Deploy as Fivetran connection: ``denver_website``
"""

from __future__ import annotations

import json
from typing import Any

from fivetran_connector_sdk import Connector
from fivetran_connector_sdk import Logging as log

from sync_pages import TABLE_NAME, sync_pages, validate_configuration


def schema(configuration: dict[str, Any]) -> list[dict[str, Any]]:
    """Define destination table and primary key."""
    return [{"table": TABLE_NAME, "primary_key": ["page_id"]}]


def update(configuration: dict[str, Any], state: dict[str, Any]) -> None:
    """Crawl configured denverwater.org pages and upsert denverwater_pages."""
    log.warning("Denver Water Website Connector: starting sync")

    validate_configuration(configuration)

    try:
        sync_pages(configuration, state)
    except Exception as exc:
        raise RuntimeError(f"Denver Water website sync failed: {exc}") from exc


connector = Connector(update=update, schema=schema)

if __name__ == "__main__":
    with open("configuration.json", "r", encoding="utf-8") as config_file:
        local_configuration = json.load(config_file)
    connector.debug(configuration=local_configuration)
