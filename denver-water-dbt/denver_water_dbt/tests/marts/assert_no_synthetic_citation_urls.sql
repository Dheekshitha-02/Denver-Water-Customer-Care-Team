-- Synthetic Genesys / CC&B records must never carry a URL that could be read as a
-- genuine citation.
select 'export__customer_context' as export_model, id, url
from {{ ref('export__customer_context') }}
where url is not null

union all

select 'export__interaction_context', id, url
from {{ ref('export__interaction_context') }}
where url is not null
