-- One row per interaction: labels for queue, agent and wrap-up, the customer
-- participant, the ordered transcript and the CC&B customer match.
with customer_participant as (
    select *
    from {{ ref('stg_genesys__participants') }}
    where participant_type = 'customer'
    qualify row_number() over (partition by interaction_id order by joined_at, participant_id) = 1
)

select
    i.interaction_id,
    i.conversation_id,
    i.channel,
    i.direction,
    i.interaction_status,
    i.interaction_reason,
    i.interaction_summary,
    i.started_at,
    i.ended_at,
    i.duration_seconds,

    i.queue_id,
    q.queue_name,
    i.agent_user_id,
    u.full_name as agent_name,
    u.role as agent_role,
    u.department as agent_department,
    i.wrap_up_code_id,
    w.wrap_up_code,
    w.wrap_up_name,

    cp.display_name as customer_display_name,
    i.customer_phone,
    i.customer_email,

    t.transcript_turn_count,
    t.transcript_text,

    m.match_method,
    m.matched_contact_field,
    m.match_candidate_count,
    m.person_id,
    m.account_id,
    m.account_pick_reason,
    a.account_number,

    i.synced_at
from {{ ref('stg_genesys__interactions') }} as i
left join {{ ref('stg_genesys__queues') }} as q
    on i.queue_id = q.queue_id
left join {{ ref('stg_genesys__users') }} as u
    on i.agent_user_id = u.user_id
left join {{ ref('stg_genesys__wrap_up_codes') }} as w
    on i.wrap_up_code_id = w.wrap_up_code_id
left join customer_participant as cp
    on i.interaction_id = cp.interaction_id
left join {{ ref('int_interactions__transcript') }} as t
    on i.interaction_id = t.interaction_id
left join {{ ref('int_interactions__customer_match') }} as m
    on i.interaction_id = m.interaction_id
left join {{ ref('stg_ccb__accounts') }} as a
    on m.account_id = a.account_id
