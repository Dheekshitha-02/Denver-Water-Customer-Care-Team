select
    transcript_id,
    interaction_id,
    cast(sequence_number as integer) as sequence_number,
    speaker,
    {{ full_trim('message') }} as message,
    {{ normalize_timestamp('spoken_at') }} as spoken_at,
    {{ normalize_timestamp('_fivetran_synced') }} as synced_at
from {{ source('genesys', 'transcripts') }}
where coalesce(_fivetran_deleted, false) = false
