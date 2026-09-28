-- Snowflake-only: SharePoint is replicated only to Snowflake (disabled on DuckDB
-- dev), and custom_metadata is a VARIANT. File metadata only; no document text.
with files as (
    select
        file_id,
        _fivetran_file_path as file_path,
        coalesce(
            custom_metadata:FileLeafRef::varchar,
            split_part(_fivetran_file_path, '/', -1)
        ) as file_name,
        url,
        size,
        created_at,
        modified_at,
        custom_metadata,
        _fivetran_synced
    from {{ source('sharepoint', 'sharepoint_knowledge') }}
    where coalesce(_fivetran_deleted, false) = false
)

select
    file_id,
    'sharepoint' as source_system,
    file_path,
    file_name,
    lower(split_part(file_name, '.', -1)) as file_extension,
    -- e.g. KB-001, OPS-001; null for support files (README, manifest).
    regexp_substr(file_name, '^[A-Z]+-[0-9]+') as document_code,
    trim(replace(
        regexp_replace(regexp_replace(file_name, '\\.[^.]+$', ''), '^[A-Z]+-[0-9]+_', ''),
        '_', ' '
    )) as document_title,
    lower(split_part(file_name, '.', -1)) = 'docx' as is_knowledge_document,
    url as source_url,
    cast(size as bigint) as size_bytes,
    {{ normalize_timestamp('created_at') }} as created_at,
    {{ normalize_timestamp('modified_at') }} as modified_at,
    custom_metadata:ContentType::varchar as sharepoint_content_type,
    custom_metadata,
    {{ normalize_timestamp('_fivetran_synced') }} as synced_at
from files
