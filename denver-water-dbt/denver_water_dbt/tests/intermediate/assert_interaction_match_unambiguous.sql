-- No interaction may match more than one CC&B person. Ambiguous interactions are
-- left without a customer by design, but any occurrence needs review.
select interaction_id, match_candidate_count
from {{ ref('int_interactions__customer_match') }}
where match_candidate_count > 1
