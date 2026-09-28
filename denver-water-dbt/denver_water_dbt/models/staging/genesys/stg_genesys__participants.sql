select
    participant_id,
    interaction_id,
    participant_type,
    user_id,
    display_name,
    phone,
    {{ normalize_phone('phone') }} as phone_norm,
    {{ normalize_timestamp('joined_at') }} as joined_at,
    {{ normalize_timestamp('left_at') }} as left_at,
    {{ normalize_timestamp('_fivetran_synced') }} as synced_at
from {{ source('genesys', 'participants') }}
where coalesce(_fivetran_deleted, false) = false
