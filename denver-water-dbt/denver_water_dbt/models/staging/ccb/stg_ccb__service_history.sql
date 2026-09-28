select
    service_history_id,
    account_id,
    premise_id,
    person_id,
    event_type,
    {{ normalize_date('effective_date') }} as effective_date,
    previous_value,
    new_value,
    notes as history_notes,
    {{ normalize_timestamp('_fivetran_synced') }} as synced_at
from {{ source('ccb', 'service_history') }}
where coalesce(_fivetran_deleted, false) = false
