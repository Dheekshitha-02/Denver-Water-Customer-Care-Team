{{ config(severity='warn') }}

-- Early warning if normalization or source data changes break the customer match.
-- The synthetic data matches 100%; warn when fewer than 90% of interactions match.
select
    count(*) as interactions,
    count(person_id) as matched_interactions
from {{ ref('int_interactions__customer_match') }}
having count(person_id) < 0.9 * count(*)
