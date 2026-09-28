# Denver Water CCB → Fivetran connector

Custom [Fivetran Connector SDK](https://fivetran.com/docs/connector-sdk/setup-guide) connector that reads synthetic Oracle CC&B data from **Supabase Postgres** schema ``ccb_mock`` and upserts rows **as-is** (no transformations, joins, or Autotask shaping).

**Source project (PoC):** `dytwnujgjxmjrltgfawy`  
**Fivetran connection name:** `denver_ccb`  
**Twin pattern:** Kaseya [`supabase-fivetran-connector`](../../Kaseya-KnowledgeHub/supabase-fivetran-connector)

## What it syncs (13 tables)

| Table | Primary key |
|-------|-------------|
| `persons` | `person_id` |
| `accounts` | `account_id` |
| `account_persons` | `account_person_id` |
| `premises` | `premise_id` |
| `service_points` | `service_point_id` |
| `meters` | `meter_id` |
| `bills` | `bill_id` |
| `payments` | `payment_id` |
| `consumption` | `consumption_id` |
| `contact_notes` | `contact_note_id` |
| `field_activities` | `field_activity_id` |
| `service_history` | `service_history_id` |
| `lead_program` | `lead_program_id` |

### Sync strategy (POC)

These tables do **not** have reliable `updated_at` / CDC columns. The connector therefore:

1. **Full-reads** each table on every sync (ordered by primary key, keyset-paginated).
2. **Upserts** every row using the declared text primary key so repeats are idempotent (no warehouse duplicates).
3. Does **not** invent or require `updated_at` on the source.

## Setup

```powershell
cd Denver_Water\ccb-fivetran-connector
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
copy configuration.json.example configuration.json
# Edit configuration.json with Supabase pooler host + DB password
# Keep "schema": "ccb_mock"
```

### configuration.json

| Key | Required | Description |
|-----|----------|-------------|
| `host` | Yes | Pooler host (e.g. `aws-0-us-west-2.pooler.supabase.com`) |
| `port` | No | Default `5432` |
| `database` | Yes | Usually `postgres` |
| `user` | Yes | e.g. `postgres.dytwnujgjxmjrltgfawy` |
| `password` | Yes | Database password |
| `schema` | Yes | Must be `ccb_mock` |
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
  --connection denver_ccb `
  --configuration configuration.json
```

Unpause in the Fivetran UI. Warehouse schema typically follows the connection name (`DENVER_CCB` / `denver_ccb`).

## Layout

| File | Role |
|------|------|
| `connector.py` | Fivetran entry (`schema` / `update`) |
| `entity_registry.py` | 13 tables + text primary keys |
| `supabase_client.py` | Postgres reads + pagination |
| `record_utils.py` | JSON-safe pass-through (no remapping) |
| `sync_entities.py` | Sync loop, checkpoints, upserts |
