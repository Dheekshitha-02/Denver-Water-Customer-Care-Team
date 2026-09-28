select
    payment_id,
    account_id,
    bill_id,
    {{ normalize_date('payment_date') }} as payment_date,
    cast(payment_amount as decimal(12, 2)) as payment_amount,
    payment_method,
    payment_status,
    confirmation_number,
    {{ normalize_timestamp('_fivetran_synced') }} as synced_at
from {{ source('ccb', 'payments') }}
where coalesce(_fivetran_deleted, false) = false
