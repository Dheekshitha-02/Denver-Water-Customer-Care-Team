-- Phone or email is the only way to match an interaction to a CC&B customer.
select interaction_id
from {{ source('genesys', 'interactions') }}
where coalesce(_fivetran_deleted, false) = false
  and coalesce(trim(customer_phone), '') = ''
  and coalesce(trim(customer_email), '') = ''
