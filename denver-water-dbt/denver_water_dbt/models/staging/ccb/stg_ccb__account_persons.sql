select
    account_person_id,
    account_id,
    person_id,
    relationship_type,
    cast(is_primary as boolean) as is_primary,
    {{ normalize_date('start_date') }} as start_date,
    {{ normalize_timestamp('_fivetran_synced') }} as synced_at
from {{ source('ccb', 'account_persons') }}
where coalesce(_fivetran_deleted, false) = false
