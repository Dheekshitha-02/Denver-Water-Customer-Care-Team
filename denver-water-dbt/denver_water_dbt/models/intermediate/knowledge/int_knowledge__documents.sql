-- All knowledge documents (public website + internal SharePoint) in one shape.
-- Includes SharePoint rows without content; the knowledge export filters on
-- is_content_available.
{% set columns = [
    'document_id', 'source_system', 'source_record_id', 'document_type', 'visibility',
    'title', 'source_url', 'category', 'category_group', 'summary',
    'content', 'content_length', 'content_hash',
    'last_modified_at', 'content_as_of_at', 'content_as_of_basis',
    'is_content_available', 'synced_at'
] %}

select {{ columns | join(', ') }}
from {{ ref('int_knowledge__website_documents') }}

{% if var('enable_sharepoint', target.type != 'duckdb') %}
union all

select {{ columns | join(', ') }}
from {{ ref('int_knowledge__sharepoint_documents') }}
{% endif %}
