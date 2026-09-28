-- Transcript turns are ordered by sequence_number, so it must be unique per interaction.
select interaction_id, sequence_number, count(*) as turn_count
from {{ source('genesys', 'transcripts') }}
where coalesce(_fivetran_deleted, false) = false
group by interaction_id, sequence_number
having count(*) > 1
