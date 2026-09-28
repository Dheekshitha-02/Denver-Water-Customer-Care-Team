-- Genesys -> CC&B customer match outcome, one row per match_method / account_pick_reason.
select
    match_method,
    coalesce(account_pick_reason, 'n/a') as account_pick_reason,
    count(*) as interaction_count,
    round(100.0 * count(*) / sum(count(*)) over (), 1) as pct_of_interactions,
    count(account_id) as interactions_with_account,
    count(distinct account_id) as distinct_accounts
from {{ ref('int_interactions__customer_match') }}
group by 1, 2
