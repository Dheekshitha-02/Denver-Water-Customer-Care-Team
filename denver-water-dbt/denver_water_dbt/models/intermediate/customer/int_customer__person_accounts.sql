-- One row per person-to-account relationship, with the normalized contact points
-- used to find a customer from a phone number or email.
select
    ap.account_person_id,
    ap.account_id,
    a.account_number,
    a.account_status,
    ap.person_id,
    p.full_name,
    p.first_name,
    p.last_name,
    ap.relationship_type,
    ap.is_primary,
    ap.start_date as relationship_start_date,
    p.phone,
    p.alternate_phone,
    p.email,
    p.phone_norm,
    p.alternate_phone_norm,
    p.email_norm,
    p.preferred_contact_method,
    p.is_active as person_is_active
from {{ ref('stg_ccb__account_persons') }} as ap
inner join {{ ref('stg_ccb__persons') }} as p
    on ap.person_id = p.person_id
inner join {{ ref('stg_ccb__accounts') }} as a
    on ap.account_id = a.account_id
