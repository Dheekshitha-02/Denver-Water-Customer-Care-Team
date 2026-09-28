-- Knowledge documents per source: how many exist, how many have text, and how many
-- reached the AI export (only content-available documents are exported).
with documents as (
    select
        source_system,
        visibility,
        count(*) as document_count,
        count_if(is_content_available) as content_available_count,
        count(source_url) as with_source_url_count,
        min(content_length) as min_content_length,
        max(content_length) as max_content_length,
        max(synced_at) as last_synced_at
    from {{ ref('int_knowledge__documents') }}
    group by 1, 2
),

exported as (
    select source_system, count(*) as exported_count
    from {{ ref('export__knowledge_context') }}
    group by 1
)

select
    d.*,
    coalesce(e.exported_count, 0) as exported_count,
    d.document_count - coalesce(e.exported_count, 0) as not_exported_count
from documents as d
left join exported as e
    on d.source_system = e.source_system
