select
    account_id,
    cast(account_number as varchar) as account_number,
    account_type,
    account_status,
    billing_cycle,
    cast(current_balance as decimal(12, 2)) as current_balance,
    cast(past_due_amount as decimal(12, 2)) as past_due_amount,
    cast(autopay_enabled as boolean) as is_autopay_enabled,
    cast(paperless_billing as boolean) as is_paperless_billing,
    {{ normalize_date('created_at') }} as account_created_date,
    {{ normalize_timestamp('_fivetran_synced') }} as synced_at
from {{ source('ccb', 'accounts') }}
where coalesce(_fivetran_deleted, false) = false
