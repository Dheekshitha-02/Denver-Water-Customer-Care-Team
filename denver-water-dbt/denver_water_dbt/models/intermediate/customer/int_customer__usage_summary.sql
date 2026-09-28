-- One row per account: latest meter read period and trailing 12-month usage,
-- anchored on the account's latest period_end.
with consumption as (
    select
        *,
        max(period_end) over (partition by account_id) as anchor_period_end
    from {{ ref('stg_ccb__consumption') }}
),

latest as (
    select *
    from consumption
    qualify row_number() over (partition by account_id order by period_end desc, consumption_id desc) = 1
),

totals as (
    select
        account_id,
        count(*) as usage_period_count,
        avg(case when period_end > {{ dbt.dateadd('month', -12, 'anchor_period_end') }} then usage_gallons end)
            as avg_usage_gallons_12m,
        count(case when period_end > {{ dbt.dateadd('month', -12, 'anchor_period_end') }} and usage_flag = 'HIGH' then 1 end)
            as high_usage_periods_12m,
        count(case when period_end > {{ dbt.dateadd('month', -12, 'anchor_period_end') }} and usage_flag = 'LOW' then 1 end)
            as low_usage_periods_12m
    from consumption
    group by account_id
)

select
    a.account_id,
    l.consumption_id as latest_consumption_id,
    l.period_start as latest_usage_period_start,
    l.period_end as latest_usage_period_end,
    l.usage_gallons as latest_usage_gallons,
    l.current_read as latest_meter_read,
    l.read_type as latest_read_type,
    l.usage_flag as latest_usage_flag,
    coalesce(t.usage_period_count, 0) as usage_period_count,
    cast(round(t.avg_usage_gallons_12m, 0) as bigint) as avg_usage_gallons_12m,
    cast(round(100.0 * (l.usage_gallons - t.avg_usage_gallons_12m) / nullif(t.avg_usage_gallons_12m, 0), 1) as decimal(8, 1))
        as latest_usage_vs_12m_avg_pct,
    coalesce(t.high_usage_periods_12m, 0) as high_usage_periods_12m,
    coalesce(t.low_usage_periods_12m, 0) as low_usage_periods_12m
from {{ ref('stg_ccb__accounts') }} as a
left join latest as l
    on a.account_id = l.account_id
left join totals as t
    on a.account_id = t.account_id
