select
    person_id,
    first_name,
    last_name,
    trim(coalesce(first_name, '') || ' ' || coalesce(last_name, '')) as full_name,
    person_type,
    phone,
    alternate_phone,
    email,
    {{ normalize_phone('phone') }} as phone_norm,
    {{ normalize_phone('alternate_phone') }} as alternate_phone_norm,
    {{ normalize_email('email') }} as email_norm,
    preferred_contact_method,
    mailing_address,
    city,
    state,
    lpad(cast(zip_code as varchar), 5, '0') as zip_code,
    cast(active as boolean) as is_active,
    {{ normalize_timestamp('_fivetran_synced') }} as synced_at
from {{ source('ccb', 'persons') }}
where coalesce(_fivetran_deleted, false) = false
