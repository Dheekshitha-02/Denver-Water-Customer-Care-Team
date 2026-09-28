select
    wrap_up_code_id,
    code as wrap_up_code,
    name as wrap_up_name,
    description as wrap_up_description,
    cast(active as boolean) as is_active,
    {{ normalize_timestamp('_fivetran_synced') }} as synced_at
from {{ source('genesys', 'wrap_up_codes') }}
where coalesce(_fivetran_deleted, false) = false
