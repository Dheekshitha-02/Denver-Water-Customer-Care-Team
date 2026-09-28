-- Demo accounts ACC0001-ACC0008 must each export a customer document and have at
-- least one matched interaction; the Agent Assist demo scripts depend on them.
{{ config(enabled=var('poc_synthetic_data')) }}

with demo_accounts as (
    select 'ACC000' || cast(n as varchar) as account_id
    from (values (1), (2), (3), (4), (5), (6), (7), (8)) as v (n)
)

select d.account_id
from demo_accounts as d
left join {{ ref('export__customer_context') }} as c
    on d.account_id = c.account_id
left join {{ ref('export__interaction_context') }} as i
    on d.account_id = i.account_id
group by d.account_id
having count(c.account_id) = 0 or count(i.interaction_id) = 0
