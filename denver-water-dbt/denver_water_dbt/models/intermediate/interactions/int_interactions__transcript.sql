-- One row per interaction: transcript turns in sequence_number order, one line per turn.
select
    interaction_id,
    count(*) as transcript_turn_count,
    count(case when speaker = 'customer' then 1 end) as customer_turn_count,
    count(case when speaker = 'agent' then 1 end) as agent_turn_count,
    min(spoken_at) as transcript_started_at,
    max(spoken_at) as transcript_ended_at,
    {{ string_agg_ordered(
        "'[' || coalesce(" ~ format_ts('spoken_at', 'datetime_minute') ~ ", '') || '] '
         || case speaker when 'customer' then 'Customer' when 'agent' then 'Agent' else coalesce(speaker, 'Unknown') end
         || ': ' || coalesce(message, '')",
        'sequence_number',
        'line'
    ) }} as transcript_text
from {{ ref('stg_genesys__transcripts') }}
group by interaction_id
