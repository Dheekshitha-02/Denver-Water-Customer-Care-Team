select
    queue_id,
    queue_name,
    description as queue_description,
    cast(active as boolean) as is_active,
    {{ normalize_timestamp('_fivetran_synced') }} as synced_at
from {{ source('genesys', 'queues') }}
where coalesce(_fivetran_deleted, false) = false
