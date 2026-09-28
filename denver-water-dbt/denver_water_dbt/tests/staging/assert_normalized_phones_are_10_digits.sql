{{ config(severity='warn') }}

-- The customer match compares normalized phones exactly; anything other than a
-- 10-digit US number will never match and should be reviewed.
select 'genesys_interaction' as source_record, interaction_id as record_id, customer_phone_norm as phone_norm
from {{ ref('stg_genesys__interactions') }}
where customer_phone_norm is not null and length(customer_phone_norm) != 10

union all

select 'ccb_person_phone', person_id, phone_norm
from {{ ref('stg_ccb__persons') }}
where phone_norm is not null and length(phone_norm) != 10

union all

select 'ccb_person_alternate_phone', person_id, alternate_phone_norm
from {{ ref('stg_ccb__persons') }}
where alternate_phone_norm is not null and length(alternate_phone_norm) != 10
