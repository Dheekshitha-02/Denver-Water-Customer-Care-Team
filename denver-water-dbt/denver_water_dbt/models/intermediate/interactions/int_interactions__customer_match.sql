-- One row per Genesys interaction, resolved to at most one CC&B person and account.
--
-- Match order: phone (person phone or alternate phone), then email. Genesys has no
-- CC&B key, so this is the only link between the systems.
-- If the winning method matches more than one person the interaction is marked
-- 'ambiguous' and no customer is attached: showing the wrong customer's account to
-- an agent is worse than showing none.
with interactions as (
    select interaction_id, customer_phone_norm, customer_email_norm
    from {{ ref('stg_genesys__interactions') }}
),

persons as (
    select person_id, phone_norm, alternate_phone_norm, email_norm
    from {{ ref('stg_ccb__persons') }}
),

candidates as (
    select
        i.interaction_id,
        p.person_id,
        'phone' as match_method,
        1 as method_rank,
        case when i.customer_phone_norm = p.phone_norm then 'phone' else 'alternate_phone' end
            as matched_contact_field
    from interactions as i
    inner join persons as p
        on i.customer_phone_norm = p.phone_norm
        or i.customer_phone_norm = p.alternate_phone_norm
    where i.customer_phone_norm is not null

    union all

    select
        i.interaction_id,
        p.person_id,
        'email' as match_method,
        2 as method_rank,
        'email' as matched_contact_field
    from interactions as i
    inner join persons as p
        on i.customer_email_norm = p.email_norm
    where i.customer_email_norm is not null
),

best_method as (
    select *
    from candidates
    qualify method_rank = min(method_rank) over (partition by interaction_id)
),

person_match as (
    select
        interaction_id,
        min(match_method) as match_method,
        min(matched_contact_field) as matched_contact_field,
        count(distinct person_id) as match_candidate_count,
        min(person_id) as person_id
    from best_method
    group by interaction_id
),

account_pick as (
    select
        pm.interaction_id,
        pa.account_id,
        case when pa.is_primary then 'primary_relationship' else 'non_primary_relationship' end
            as account_pick_reason
    from person_match as pm
    inner join {{ ref('int_customer__person_accounts') }} as pa
        on pm.person_id = pa.person_id
    where pm.match_candidate_count = 1
    qualify row_number() over (
        partition by pm.interaction_id
        order by
            case when pa.is_primary then 0 else 1 end,
            case when pa.account_status = 'Active' then 0 else 1 end,
            pa.relationship_start_date desc,
            pa.account_id
    ) = 1
)

select
    i.interaction_id,
    case
        when pm.interaction_id is null then 'unmatched'
        when pm.match_candidate_count > 1 then 'ambiguous'
        else pm.match_method
    end as match_method,
    case when pm.match_candidate_count = 1 then pm.matched_contact_field end as matched_contact_field,
    coalesce(pm.match_candidate_count, 0) as match_candidate_count,
    case when pm.match_candidate_count = 1 then pm.person_id end as person_id,
    ap.account_id,
    case
        when pm.match_candidate_count = 1 and ap.account_id is null then 'person_has_no_account'
        else ap.account_pick_reason
    end as account_pick_reason
from interactions as i
left join person_match as pm
    on i.interaction_id = pm.interaction_id
left join account_pick as ap
    on i.interaction_id = ap.interaction_id
