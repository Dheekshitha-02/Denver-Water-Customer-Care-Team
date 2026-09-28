# Denver Water Genesys → Fivetran connector

Custom [Fivetran Connector SDK](https://fivetran.com/docs/connector-sdk/setup-guide) connector that reads synthetic Genesys Cloud contact-center data from **Supabase Postgres** schema ``genesys_mock`` and upserts rows **as-is** (no transformations, joins, customer matching, or Autotask shaping).

**Source project (PoC):** `dytwnujgjxmjrltgfawy`  
**Fivetran connection name:** `denver_genesys`  
**Twin pattern:** Kaseya [`supabase-fivetran-connector`](../../Kaseya-KnowledgeHub/supabase-fivetran-connector)

## What it syncs (6 tables)

| Table | Primary key |
|-------|-------------|
| `users` | `user_id` |
| `queues` | `queue_id` |
| `wrap_up_codes` | `wrap_up_code_id` |
| `interactions` | `interaction_id` |
| `participants` | `participant_id` |
| `transcripts` | `transcript_id` |

### Sync strategy (POC)

These tables do **not** have reliable `updated_at` / CDC columns. The connector therefore:

1. **Full-reads** each table on every sync (ordered by primary key, keyset-paginated).
2. **Upserts** every row using the declared text primary key so repeats are idempotent (no warehouse duplicates).
3. Does **not** invent or require `updated_at` on the source.
4. Does **not** treat business timestamps (`started_at`, `spoken_at`, …) as change-tracking cursors.

## Setup

```powershell
cd Denver_Water\genesys-fivetran-connector
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
copy configuration.json.example configuration.json
# Edit configuration.json with Supabase pooler host + DB password
# Keep "schema": "genesys_mock"
```

### configuration.json

| Key | Required | Description |
|-----|----------|-------------|
| `host` | Yes | Pooler host (e.g. `aws-0-us-west-2.pooler.supabase.com`) |
| `port` | No | Default `5432` |
| `database` | Yes | Usually `postgres` |
| `user` | Yes | e.g. `postgres.dytwnujgjxmjrltgfawy` |
| `password` | Yes | Database password |
| `schema` | Yes | Must be `genesys_mock` |
| `sslmode` | No | Default `require` |
| `historical_sync_start_date` | No | Reserved for optional datetime cursors; unused in full mode |

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
  --connection denver_genesys `
  --configuration configuration.json
```

Unpause in the Fivetran UI. Warehouse schema typically follows the connection name (`DENVER_GENESYS` / `denver_genesys`).

## Layout

| File | Role |
|------|------|
| `connector.py` | Fivetran entry (`schema` / `update`) |
| `entity_registry.py` | 6 tables + text primary keys |
| `supabase_client.py` | Postgres reads + pagination |
| `record_utils.py` | JSON-safe pass-through (no remapping) |
| `sync_entities.py` | Sync loop, checkpoints, upserts |
