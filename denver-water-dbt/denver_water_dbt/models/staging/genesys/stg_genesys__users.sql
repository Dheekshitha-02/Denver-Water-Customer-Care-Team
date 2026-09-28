select
    user_id,
    employee_number,
    first_name,
    last_name,
    trim(coalesce(first_name, '') || ' ' || coalesce(last_name, '')) as full_name,
    email,
    role,
    department,
    cast(active as boolean) as is_active,
    {{ normalize_timestamp('_fivetran_synced') }} as synced_at
from {{ source('genesys', 'users') }}
where coalesce(_fivetran_deleted, false) = false
