"""Sync orchestration: crawl → parse → upsert denverwater_pages."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from fivetran_connector_sdk import Logging as log
from fivetran_connector_sdk import Operations as op

from crawler import DenverWaterCrawler
from html_parser import content_hash_for_text, discover_links, page_id_for_url, parse_page
from record_utils import to_page_record

TABLE_NAME = "denverwater_pages"
STATE_HASHES = "content_hashes"
PROGRESS_LOG_INTERVAL = 5


def _split_csv(value: str) -> list[str]:
    return [part.strip() for part in (value or "").split(",") if part.strip()]


def validate_configuration(configuration: dict[str, Any]) -> None:
    """Ensure required scrape settings are present and parseable."""
    required = (
        "base_url",
        "seed_urls",
        "allowed_path_prefixes",
        "max_pages",
        "max_depth",
        "request_delay_seconds",
        "request_timeout_seconds",
        "user_agent",
    )
    for key in required:
        if not configuration.get(key):
            raise ValueError(f"Missing required configuration value: {key}")

    try:
        max_pages = int(configuration["max_pages"])
        max_depth = int(configuration["max_depth"])
        delay = float(configuration["request_delay_seconds"])
        timeout = float(configuration["request_timeout_seconds"])
    except (TypeError, ValueError) as exc:
        raise ValueError(
            "max_pages, max_depth, request_delay_seconds, and "
            "request_timeout_seconds must be numeric strings"
        ) from exc

    if max_pages < 1:
        raise ValueError("max_pages must be >= 1")
    if max_depth < 0:
        raise ValueError("max_depth must be >= 0")
    if delay < 0:
        raise ValueError("request_delay_seconds must be >= 0")
    if timeout <= 0:
        raise ValueError("request_timeout_seconds must be > 0")

    if not _split_csv(configuration["seed_urls"]):
        raise ValueError("seed_urls must contain at least one URL")
    if not _split_csv(configuration["allowed_path_prefixes"]):
        raise ValueError("allowed_path_prefixes must contain at least one prefix")


def _build_crawler(configuration: dict[str, Any]) -> DenverWaterCrawler:
    return DenverWaterCrawler(
        base_url=configuration["base_url"],
        seed_urls=_split_csv(configuration["seed_urls"]),
        allowed_path_prefixes=_split_csv(configuration["allowed_path_prefixes"]),
        max_pages=int(configuration["max_pages"]),
        max_depth=int(configuration["max_depth"]),
        request_delay_seconds=float(configuration["request_delay_seconds"]),
        request_timeout_seconds=float(configuration["request_timeout_seconds"]),
        user_agent=configuration["user_agent"],
    )


def _utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def sync_pages(configuration: dict[str, Any], state: dict[str, Any]) -> dict[str, Any]:
    """
    Crawl configured Customer Care pages and upsert into denverwater_pages.

    State keeps ``content_hashes`` for change detection across syncs.
    No queue resume in v1 — each sync starts a fresh scoped crawl.
    """
    validate_configuration(configuration)

    seen_hashes: dict[str, str] = dict(state.get(STATE_HASHES) or {})
    crawler = _build_crawler(configuration)

    fetched = 0
    upserted = 0
    unchanged = 0
    failed = 0
    skipped_empty = 0

    try:
        for _target, result in crawler.iter_crawl(discover_links):
            fetched += 1

            if not result.ok or not result.html:
                failed += 1
                continue

            parsed = parse_page(
                result.html,
                result.final_url,
                last_modified_header=result.last_modified_header,
            )

            if not parsed.content:
                skipped_empty += 1
                log.warning(f"Empty main content after parse: {result.final_url}")
                continue

            page_id = page_id_for_url(result.final_url)
            content_hash = content_hash_for_text(parsed.content)
            previous_hash = seen_hashes.get(page_id)

            if previous_hash == content_hash:
                unchanged += 1
                if fetched % PROGRESS_LOG_INTERVAL == 0:
                    log.info(
                        f"Progress: fetched={fetched} upserted={upserted} "
                        f"unchanged={unchanged} failed={failed}"
                    )
                continue

            record = to_page_record(
                {
                    "page_id": page_id,
                    "url": result.final_url,
                    "title": parsed.title,
                    "content": parsed.content,
                    "category": parsed.category,
                    "meta_description": parsed.meta_description,
                    "last_modified": parsed.last_modified,
                    "scraped_at": _utc_now(),
                    "content_hash": content_hash,
                }
            )
            op.upsert(table=TABLE_NAME, data=record)
            seen_hashes[page_id] = content_hash
            upserted += 1

            if fetched % PROGRESS_LOG_INTERVAL == 0:
                log.info(
                    f"Progress: fetched={fetched} upserted={upserted} "
                    f"unchanged={unchanged} failed={failed}"
                )
    finally:
        crawler.close()

    new_state = {STATE_HASHES: seen_hashes}
    op.checkpoint(new_state)

    log.warning(
        "Denver Water website sync complete: "
        f"fetched={fetched} upserted={upserted} unchanged={unchanged} "
        f"failed={failed} empty={skipped_empty} tracked_hashes={len(seen_hashes)}"
    )
    return new_state
