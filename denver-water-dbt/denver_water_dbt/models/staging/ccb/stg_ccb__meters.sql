select
    meter_id,
    meter_number,
    service_point_id,
    meter_size,
    meter_type,
    meter_location,
    meter_status,
    {{ normalize_date('install_date') }} as install_date,
    {{ normalize_date('last_test_date') }} as last_test_date,
    {{ normalize_date('last_exchange_date') }} as last_exchange_date,
    {{ normalize_timestamp('_fivetran_synced') }} as synced_at
from {{ source('ccb', 'meters') }}
where coalesce(_fivetran_deleted, false) = false
