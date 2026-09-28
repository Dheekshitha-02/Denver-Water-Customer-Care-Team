-- Public DenverWater.org pages in the common knowledge-document shape.
-- source_url is the genuine public page URL and is the citation.
select
    'denverwater_org:' || page_id as document_id,
    source_system,
    page_id as source_record_id,
    'web_page' as document_type,
    'public' as visibility,
    coalesce(nullif(trim(title), ''), source_url) as title,
    source_url,
    category,
    category_group,
    -- The scraper falls back to page text when a page has no meta description, which
    -- would duplicate the body; only short, genuine descriptions are kept.
    case when length(meta_description) <= 500 then meta_description end as summary,
    content,
    content_length,
    content_hash,
    last_modified_at,
    content_as_of_at,
    content_as_of_basis,
    coalesce(content_length, 0) > 0 as is_content_available,
    synced_at
from {{ ref('stg_denver_website__pages') }}
