select
    interaction_id,
    conversation_id,
    channel,
    direction,
    status as interaction_status,
    interaction_reason,
    summary as interaction_summary,
    queue_id,
    agent_user_id,
    wrap_up_code_id,
    customer_phone,
    customer_email,
    {{ normalize_phone('customer_phone') }} as customer_phone_norm,
    {{ normalize_email('customer_email') }} as customer_email_norm,
    {{ normalize_timestamp('started_at') }} as started_at,
    {{ normalize_timestamp('ended_at') }} as ended_at,
    cast(duration_seconds as integer) as duration_seconds,
    {{ normalize_timestamp('_fivetran_synced') }} as synced_at
from {{ source('genesys', 'interactions') }}
where coalesce(_fivetran_deleted, false) = false
