select
    premise_id,
    premise_number,
    account_id,
    service_address,
    city,
    state,
    lpad(cast(zip_code as varchar), 5, '0') as zip_code,
    property_type,
    service_district,
    service_status,
    cast(latitude as double) as latitude,
    cast(longitude as double) as longitude,
    {{ normalize_timestamp('_fivetran_synced') }} as synced_at
from {{ source('ccb', 'premises') }}
where coalesce(_fivetran_deleted, false) = false
