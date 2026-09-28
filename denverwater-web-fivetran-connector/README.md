# Denver Water Website → Fivetran connector

Custom [Fivetran Connector SDK](https://fivetran.com/docs/connector-sdk/setup-guide) connector that scrapes a **controlled set** of public Customer Care pages on [denverwater.org](https://www.denverwater.org) and upserts cleaned page records into ``denverwater_pages``.

**Fivetran connection name:** `denver_website`  
**Sibling connectors:** `genesys-fivetran-connector`, `ccb-fivetran-connector`

## What it syncs

| Table | Primary key |
|-------|-------------|
| `denverwater_pages` | `page_id` |

### Columns

| Column | Description |
|--------|-------------|
| `page_id` | SHA-256 of canonical URL |
| `url` | Canonical absolute URL |
| `title` | Page title |
| `content` | Cleaned main text (nav/footer/scripts removed) |
| `category` | Path-derived category |
| `meta_description` | Meta description when present |
| `last_modified` | HTTP / meta last-modified when available |
| `scraped_at` | UTC scrape timestamp |
| `content_hash` | SHA-256 of normalized content (change detection) |

### Sync strategy (POC)

1. Starts from configured Customer Care **seed URLs** (homepage is not a seed).
2. Follows internal denverwater.org links within `allowed_path_prefixes`, up to `max_pages` / `max_depth`.
3. Respects `robots.txt` and throttles requests.
4. Upserts only when `content_hash` is new or changed vs connector state.
5. Each sync runs a fresh scoped crawl (no queue resume in v1).

## Setup

```powershell
cd Denver_Water\denverwater-web-fivetran-connector
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
copy configuration.json.example configuration.json
```

### configuration.json

| Key | Required | Description |
|-----|----------|-------------|
| `base_url` | Yes | Site origin (`https://www.denverwater.org`) |
| `seed_urls` | Yes | Comma-separated Customer Care paths/URLs |
| `allowed_path_prefixes` | Yes | Comma-separated path prefixes for link following |
| `max_pages` | Yes | Cap on pages fetched per sync (default `40`) |
| `max_depth` | Yes | Max link depth from seeds (default `2`) |
| `request_delay_seconds` | Yes | Delay between HTTP requests |
| `request_timeout_seconds` | Yes | Per-request timeout |
| `user_agent` | Yes | HTTP User-Agent string |

## Local test

```powershell
fivetran debug --configuration configuration.json
```

Inspect `files/warehouse.db` (DuckDB). Reset local state with:

```powershell
fivetran reset
```

## Deploy to Fivetran

```powershell
fivetran deploy `
  --api-key <BASE64_API_KEY> `
  --destination <DESTINATION_NAME> `
  --connection denver_website `
  --configuration configuration.json
```

## Layout

| File | Role |
|------|------|
| `connector.py` | Fivetran entry (`schema` / `update`) |
| `crawler.py` | robots, throttle, scoped BFS, HTTP fetch |
| `html_parser.py` | Boilerplate strip + field extraction |
| `sync_pages.py` | Orchestration, hashes, upserts, checkpoint |
| `record_utils.py` | JSON-safe record shaping |
