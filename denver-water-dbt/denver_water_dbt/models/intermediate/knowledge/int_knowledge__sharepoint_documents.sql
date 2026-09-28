{{ config(enabled=var('enable_sharepoint', target.type != 'duckdb')) }}

-- Internal SharePoint knowledge articles in the common knowledge-document shape.
-- Metadata only: content stays null (is_content_available = false) until DOCX text
-- extraction lands as a separate source. README / manifest support files are excluded.
select
    'sharepoint:' || file_id as document_id,
    source_system,
    file_id as source_record_id,
    file_extension as document_type,
    'internal' as visibility,
    trim(coalesce(document_code || ' ', '') || document_title) as title,
    source_url,
    split_part(file_path, '/', 1) as category,
    lower(split_part(document_code, '-', 1)) as category_group,
    cast(null as varchar) as summary,
    cast(null as varchar) as content,
    cast(null as integer) as content_length,
    cast(null as varchar) as content_hash,
    modified_at as last_modified_at,
    modified_at as content_as_of_at,
    'modified_at' as content_as_of_basis,
    false as is_content_available,
    synced_at
from {{ ref('stg_sharepoint__files') }}
where is_knowledge_document
