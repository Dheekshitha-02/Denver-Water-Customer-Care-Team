-- Every account has exactly one primary person. The customer context and the
-- interaction match both rely on this to pick the account holder.
with accounts as (
    select account_id
    from {{ source('ccb', 'accounts') }}
    where coalesce(_fivetran_deleted, false) = false
),

primaries as (
    select account_id, count(*) as primary_count
    from {{ source('ccb', 'account_persons') }}
    where coalesce(_fivetran_deleted, false) = false
      and is_primary
    group by account_id
)

select a.account_id, coalesce(p.primary_count, 0) as primary_count
from accounts as a
left join primaries as p
    on a.account_id = p.account_id
where coalesce(p.primary_count, 0) != 1
