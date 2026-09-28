select
    lead_program_id,
    account_id,
    premise_id,
    service_line_material,
    lead_status,
    program_status,
    cast(replacement_required as boolean) as is_replacement_required,
    {{ normalize_date('inspection_date') }} as inspection_date,
    {{ normalize_date('replacement_date') }} as replacement_date,
    notes as program_notes,
    {{ normalize_timestamp('_fivetran_synced') }} as synced_at
from {{ source('ccb', 'lead_program') }}
where coalesce(_fivetran_deleted, false) = false
