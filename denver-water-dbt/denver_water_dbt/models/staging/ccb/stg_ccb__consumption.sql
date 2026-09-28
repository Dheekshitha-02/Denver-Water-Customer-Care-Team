select
    consumption_id,
    account_id,
    premise_id,
    meter_id,
    {{ normalize_date('period_start') }} as period_start,
    {{ normalize_date('period_end') }} as period_end,
    cast(previous_read as bigint) as previous_read,
    cast(current_read as bigint) as current_read,
    cast(usage_gallons as bigint) as usage_gallons,
    read_type,
    usage_flag,
    {{ normalize_timestamp('_fivetran_synced') }} as synced_at
from {{ source('ccb', 'consumption') }}
where coalesce(_fivetran_deleted, false) = false
