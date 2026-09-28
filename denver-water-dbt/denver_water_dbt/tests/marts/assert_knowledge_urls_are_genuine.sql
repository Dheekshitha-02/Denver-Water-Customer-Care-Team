-- Knowledge citations must point at the real source: public DenverWater.org pages
-- or the internal SharePoint site.
select id, source_system, url
from {{ ref('export__knowledge_context') }}
where not (
    (source_system = 'denverwater_org' and url like 'https://www.denverwater.org/%')
    or (source_system = 'sharepoint' and url like 'https://%.sharepoint.com/%')
)
