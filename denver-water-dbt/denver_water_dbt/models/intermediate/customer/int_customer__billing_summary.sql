-- One row per account: latest bill, open bills, last payment and trailing
-- 12-month totals. The 12-month window is anchored on the account's latest bill
-- date (not today), so it stays meaningful on static synthetic data.
with bills as (
    select
        *,
        max(bill_date) over (partition by account_id) as anchor_bill_date
    from {{ ref('stg_ccb__bills') }}
),

latest_bill as (
    select *
    from bills
    qualify row_number() over (partition by account_id order by bill_date desc, bill_id desc) = 1
),

bill_totals as (
    select
        account_id,
        count(*) as bill_count,
        count(case when bill_status = 'Open' then 1 end) as open_bill_count,
        sum(case when bill_status = 'Open' then remaining_balance else 0 end) as open_bill_balance,
        sum(case when bill_date > {{ dbt.dateadd('month', -12, 'anchor_bill_date') }} then total_amount else 0 end)
            as billed_amount_12m,
        avg(case when bill_date > {{ dbt.dateadd('month', -12, 'anchor_bill_date') }} then total_amount end)
            as avg_bill_amount_12m
    from bills
    group by account_id
),

payments as (
    select
        p.*,
        lb.anchor_bill_date
    from {{ ref('stg_ccb__payments') }} as p
    left join latest_bill as lb
        on p.account_id = lb.account_id
),

last_payment as (
    select *
    from payments
    qualify row_number() over (partition by account_id order by payment_date desc, payment_id desc) = 1
),

payment_totals as (
    select
        account_id,
        count(*) as payment_count,
        sum(case when payment_date > {{ dbt.dateadd('month', -12, 'anchor_bill_date') }} then payment_amount else 0 end)
            as paid_amount_12m
    from payments
    group by account_id
)

select
    a.account_id,
    lb.bill_id as latest_bill_id,
    lb.bill_date as latest_bill_date,
    lb.due_date as latest_bill_due_date,
    lb.billing_period_start as latest_billing_period_start,
    lb.billing_period_end as latest_billing_period_end,
    lb.total_amount as latest_bill_amount,
    lb.remaining_balance as latest_bill_remaining_balance,
    lb.bill_status as latest_bill_status,
    coalesce(bt.bill_count, 0) as bill_count,
    coalesce(bt.open_bill_count, 0) as open_bill_count,
    coalesce(bt.open_bill_balance, 0) as open_bill_balance,
    coalesce(bt.billed_amount_12m, 0) as billed_amount_12m,
    cast(bt.avg_bill_amount_12m as decimal(12, 2)) as avg_bill_amount_12m,
    lp.payment_id as last_payment_id,
    lp.payment_date as last_payment_date,
    lp.payment_amount as last_payment_amount,
    lp.payment_method as last_payment_method,
    lp.payment_status as last_payment_status,
    lp.confirmation_number as last_payment_confirmation_number,
    coalesce(pt.payment_count, 0) as payment_count,
    coalesce(pt.paid_amount_12m, 0) as paid_amount_12m
from {{ ref('stg_ccb__accounts') }} as a
left join latest_bill as lb
    on a.account_id = lb.account_id
left join bill_totals as bt
    on a.account_id = bt.account_id
left join last_payment as lp
    on a.account_id = lp.account_id
left join payment_totals as pt
    on a.account_id = pt.account_id
