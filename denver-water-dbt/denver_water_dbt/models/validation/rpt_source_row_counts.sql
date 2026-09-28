-- Row counts per raw Fivetran table vs. its staging model.
-- staged_rows should equal raw_active_rows (staging only drops soft-deleted rows).
{% set tables = [
    ('genesys', 'users', 'stg_genesys__users'),
    ('genesys', 'queues', 'stg_genesys__queues'),
    ('genesys', 'wrap_up_codes', 'stg_genesys__wrap_up_codes'),
    ('genesys', 'interactions', 'stg_genesys__interactions'),
    ('genesys', 'participants', 'stg_genesys__participants'),
    ('genesys', 'transcripts', 'stg_genesys__transcripts'),
    ('ccb', 'persons', 'stg_ccb__persons'),
    ('ccb', 'accounts', 'stg_ccb__accounts'),
    ('ccb', 'account_persons', 'stg_ccb__account_persons'),
    ('ccb', 'premises', 'stg_ccb__premises'),
    ('ccb', 'service_points', 'stg_ccb__service_points'),
    ('ccb', 'meters', 'stg_ccb__meters'),
    ('ccb', 'bills', 'stg_ccb__bills'),
    ('ccb', 'payments', 'stg_ccb__payments'),
    ('ccb', 'consumption', 'stg_ccb__consumption'),
    ('ccb', 'contact_notes', 'stg_ccb__contact_notes'),
    ('ccb', 'field_activities', 'stg_ccb__field_activities'),
    ('ccb', 'service_history', 'stg_ccb__service_history'),
    ('ccb', 'lead_program', 'stg_ccb__lead_program'),
    ('denver_website', 'denverwater_pages', 'stg_denver_website__pages'),
] %}
{% if var('enable_sharepoint', target.type != 'duckdb') %}
    {% do tables.append(('sharepoint', 'sharepoint_knowledge', 'stg_sharepoint__files')) %}
{% endif %}

{% for source_name, table_name, staging_model in tables %}
select
    '{{ source_name }}' as source_name,
    '{{ table_name }}' as source_table,
    '{{ staging_model }}' as staging_model,
    raw.raw_rows,
    raw.raw_active_rows,
    stg.staged_rows,
    stg.staged_rows = raw.raw_active_rows as is_row_count_match
from (
    select
        count(*) as raw_rows,
        count_if(coalesce(_fivetran_deleted, false) = false) as raw_active_rows
    from {{ source(source_name, table_name) }}
) as raw
cross join (
    select count(*) as staged_rows from {{ ref(staging_model) }}
) as stg
{% if not loop.last %}union all{% endif %}
{% endfor %}
