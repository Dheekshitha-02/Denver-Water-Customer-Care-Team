-- The interaction context takes the customer's display name from the single
-- customer participant row.
with interactions as (
    select interaction_id
    from {{ source('genesys', 'interactions') }}
    where coalesce(_fivetran_deleted, false) = false
),

customers as (
    select interaction_id, count(*) as customer_count
    from {{ source('genesys', 'participants') }}
    where coalesce(_fivetran_deleted, false) = false
      and participant_type = 'customer'
    group by interaction_id
)

select i.interaction_id, coalesce(c.customer_count, 0) as customer_count
from interactions as i
left join customers as c
    on i.interaction_id = c.interaction_id
where coalesce(c.customer_count, 0) != 1
