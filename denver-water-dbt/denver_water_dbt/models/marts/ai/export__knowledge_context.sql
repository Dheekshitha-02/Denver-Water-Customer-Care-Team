-- AI-facing knowledge context: one row per knowledge document with content.
-- Only content-available sources are exported: DenverWater.org today; SharePoint
-- rows appear automatically once DOCX text extraction populates their content.
-- url is the genuine citation (public page URL or internal SharePoint URL).
{% set frontmatter = [
    "'document_id: ' || " ~ yaml_value('document_id'),
    "'source_system: ' || " ~ yaml_value('source_system'),
    "'visibility: ' || " ~ yaml_value('visibility'),
    "'document_type: ' || " ~ yaml_value('document_type'),
    "'category: ' || " ~ yaml_value('category'),
    "'source_url: ' || " ~ yaml_value('source_url'),
    "'content_as_of: ' || " ~ yaml_value(format_ts('content_as_of_at')),
    "'content_as_of_basis: ' || " ~ yaml_value('content_as_of_basis'),
    "'content_hash: ' || " ~ yaml_value('content_hash'),
] %}

select
    -- OKF contract
    document_id as id,
    title,
    source_url as url,
    '---' || chr(10)
    || {{ frontmatter | join(" || chr(10) || ") }} || chr(10)
    || '---' || chr(10) || chr(10)
    || '# ' || title || chr(10) || chr(10)
    || coalesce(nullif(trim(summary), '') || chr(10) || chr(10), '')
    || content as content,

    -- Structured context
    document_id,
    source_system,
    source_record_id,
    document_type,
    visibility,
    title as document_title,
    source_url,
    category,
    category_group,
    summary,
    content as document_text,
    content_length,
    content_hash,
    last_modified_at,
    content_as_of_at,
    content_as_of_basis,
    synced_at
from {{ ref('int_knowledge__documents') }}
where is_content_available
