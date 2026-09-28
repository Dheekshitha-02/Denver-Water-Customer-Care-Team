select
    page_id,
    'denverwater_org' as source_system,
    url as source_url,
    title,
    meta_description,
    category,
    split_part(category, '/', 1) as category_group,
    {{ full_trim('content') }} as content,
    length({{ full_trim('content') }}) as content_length,
    content_hash,
    {{ normalize_timestamp('last_modified') }} as last_modified_at,
    {{ normalize_timestamp('scraped_at') }} as scraped_at,
    -- last_modified is often absent on DenverWater.org pages.
    coalesce(
        {{ normalize_timestamp('last_modified') }},
        {{ normalize_timestamp('scraped_at') }}
    ) as content_as_of_at,
    case
        when last_modified is not null then 'last_modified'
        else 'scraped_at'
    end as content_as_of_basis,
    {{ normalize_timestamp('_fivetran_synced') }} as synced_at
from {{ source('denver_website', 'denverwater_pages') }}
where coalesce(_fivetran_deleted, false) = false
