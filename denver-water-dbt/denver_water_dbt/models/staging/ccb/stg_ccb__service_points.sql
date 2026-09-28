select
    service_point_id,
    premise_id,
    service_point_type,
    service_status,
    service_area,
    tap_number,
    {{ normalize_date('install_date') }} as install_date,
    {{ normalize_timestamp('_fivetran_synced') }} as synced_at
from {{ source('ccb', 'service_points') }}
where coalesce(_fivetran_deleted, false) = false
