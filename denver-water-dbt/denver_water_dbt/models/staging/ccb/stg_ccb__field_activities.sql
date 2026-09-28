select
    field_activity_id,
    account_id,
    premise_id,
    service_point_id,
    activity_type,
    activity_status,
    activity_status != 'Completed' as is_open,
    priority,
    service_area,
    dispatch_group,
    {{ normalize_date('scheduled_date') }} as scheduled_date,
    {{ normalize_date('completed_date') }} as completed_date,
    instructions,
    resolution_notes,
    {{ normalize_date('created_at') }} as created_date,
    {{ normalize_timestamp('_fivetran_synced') }} as synced_at
from {{ source('ccb', 'field_activities') }}
where coalesce(_fivetran_deleted, false) = false
