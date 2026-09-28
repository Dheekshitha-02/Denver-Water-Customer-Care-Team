select
    bill_id,
    account_id,
    {{ normalize_date('billing_period_start') }} as billing_period_start,
    {{ normalize_date('billing_period_end') }} as billing_period_end,
    {{ normalize_date('bill_date') }} as bill_date,
    {{ normalize_date('due_date') }} as due_date,
    cast(previous_balance as decimal(12, 2)) as previous_balance,
    cast(water_charge as decimal(12, 2)) as water_charge,
    cast(service_charge as decimal(12, 2)) as service_charge,
    cast(other_charges as decimal(12, 2)) as other_charges,
    cast(total_amount as decimal(12, 2)) as total_amount,
    cast(amount_paid as decimal(12, 2)) as amount_paid,
    cast(remaining_balance as decimal(12, 2)) as remaining_balance,
    bill_status,
    {{ normalize_timestamp('_fivetran_synced') }} as synced_at
from {{ source('ccb', 'bills') }}
where coalesce(_fivetran_deleted, false) = false
