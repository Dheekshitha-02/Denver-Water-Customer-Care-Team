select
    contact_note_id,
    account_id,
    person_id,
    {{ normalize_date('contact_date') }} as contact_date,
    contact_type,
    contact_class,
    channel,
    subject,
    {{ full_trim('note_text') }} as note_text,
    -- Genesys user_id of the authoring agent.
    created_by as created_by_user_id,
    source as note_source,
    {{ normalize_timestamp('_fivetran_synced') }} as synced_at
from {{ source('ccb', 'contact_notes') }}
where coalesce(_fivetran_deleted, false) = false
