-- AI-facing interaction context: one row per Genesys interaction.
-- Hybrid shape: structured columns plus the OKF contract (id / title / url / content).
-- url is null: the POC has no genuine Genesys deep link. The Customer Snapshot is a
-- bounded slice of the matched account (full history lives in export__customer_context).
{% set frontmatter = [
    "'interaction_id: ' || " ~ yaml_value('i.interaction_id'),
    "'conversation_id: ' || " ~ yaml_value('i.conversation_id'),
    "'channel: ' || " ~ yaml_value('i.channel'),
    "'direction: ' || " ~ yaml_value('i.direction'),
    "'status: ' || " ~ yaml_value('i.interaction_status'),
    "'queue: ' || " ~ yaml_value('i.queue_name'),
    "'agent: ' || " ~ yaml_value('i.agent_name'),
    "'wrap_up: ' || " ~ yaml_value('i.wrap_up_name'),
    "'started_at: ' || " ~ yaml_value(format_ts('i.started_at', 'datetime_minute')),
    "'duration_seconds: ' || " ~ yaml_value('i.duration_seconds'),
    "'customer: ' || " ~ yaml_value('coalesce(c.primary_person_name, i.customer_display_name)'),
    "'account_number: ' || " ~ yaml_value('i.account_number'),
    "'match_method: ' || " ~ yaml_value('i.match_method'),
    "'source_system: genesys_cloud'",
    "'source_reference: ' || " ~ yaml_value("'genesys:interaction:' || i.interaction_id"),
    "'data_classification: ' || " ~ yaml_value('data_classification'),
] %}

{% set body = [
    "'# Interaction Summary'", "''",
    md_line('Reason', 'i.interaction_reason'),
    md_line('Channel', "i.channel || ' / ' || i.direction"),
    md_line('Queue', 'i.queue_name'),
    md_line('Agent', "i.agent_name || coalesce(' (' || i.agent_role || ', ' || i.agent_department || ')', '')"),
    md_line('Started', format_ts('i.started_at', 'datetime_minute') ~ " || ' UTC'"),
    md_line('Duration', "cast(i.duration_seconds as varchar) || ' seconds'"),
    md_line('Wrap-up', "i.wrap_up_name || coalesce(' (' || i.wrap_up_code || ')', '')"),
    md_line('Summary', 'i.interaction_summary'),
    "''",
    "'# Transcript'", "''",
    md_list_or('i.transcript_text', 'No transcript available.'),
    "''",
    "'# Customer Snapshot'", "''",
    "case when c.account_id is null then '_No CC&B customer matched to this interaction._' else "
        ~ md_line('Customer', "c.primary_person_name || coalesce(' (' || c.primary_relationship_type || ')', '')") ~ " || chr(10) || "
        ~ md_line('Account', "c.account_number || coalesce(' - ' || c.account_status || ' ' || c.account_type, '')") ~ " || chr(10) || "
        ~ md_line('Service address', 'c.full_service_address') ~ " || chr(10) || "
        ~ md_line('Current balance', md_money('c.current_balance')) ~ " || chr(10) || "
        ~ md_line('Past due amount', md_money('c.past_due_amount')) ~ " || chr(10) || "
        ~ md_line('Latest bill', md_money('c.latest_bill_amount') ~ " || coalesce(' (' || c.latest_bill_status || ')', '')") ~ " || chr(10) || "
        ~ md_line('Latest usage', "cast(c.latest_usage_gallons as varchar) || ' gallons' || coalesce(' (' || c.latest_usage_flag || ')', '')") ~ " || chr(10) || "
        ~ md_line('Lead program', "coalesce(c.lead_status || coalesce(' - ' || c.lead_program_status, ''), 'No Lead Reduction Program record')") ~ " || chr(10) || "
        ~ md_line('Open field activities', 'c.open_field_activity_count') ~ " || chr(10) || chr(10) || "
        ~ md_list_or('c.open_field_activities_md', 'No open field activities.') ~ " || chr(10) || chr(10) || "
        ~ "'Recent contact notes:' || chr(10) || chr(10) || "
        ~ md_list_or('c.recent_contact_notes_md', 'No contact notes.')
        ~ " end",
    "''",
    "'# Customer Match'", "''",
    md_line('Method', 'i.match_method'),
    md_line('Matched on', 'i.matched_contact_field'),
    md_line('Candidate customers', 'i.match_candidate_count'),
    md_line('CC&B person', 'i.person_id'),
    md_line('CC&B account', 'i.account_id'),
    md_line('Account selection', 'i.account_pick_reason'),
] %}

with interactions as (
    select
        *,
        {% if var('poc_synthetic_data') %}'synthetic_poc'{% else %}'production'{% endif %} as data_classification
    from {{ ref('int_interactions__enriched') }}
)

select
    -- OKF contract
    i.interaction_id as id,
    upper(left(i.channel, 1)) || substr(i.channel, 2) || ' ' || i.direction || ' - '
        || coalesce(i.interaction_reason, 'Interaction')
        || coalesce(' (' || {{ format_ts('i.started_at') }} || ')', '') as title,
    cast(null as varchar) as url,
    '---' || chr(10)
    || {{ frontmatter | join(" || chr(10) || ") }} || chr(10)
    || '---' || chr(10) || chr(10)
    || {{ body | join(" || chr(10) || ") }} as content,

    -- Structured context
    i.interaction_id,
    i.conversation_id,
    i.channel,
    i.direction,
    i.interaction_status,
    i.interaction_reason,
    i.interaction_summary,
    i.started_at,
    i.ended_at,
    i.duration_seconds,
    i.queue_id,
    i.queue_name,
    i.agent_user_id,
    i.agent_name,
    i.wrap_up_code_id,
    i.wrap_up_code,
    i.wrap_up_name,
    i.customer_display_name,
    i.customer_phone,
    i.customer_email,
    i.transcript_turn_count,
    i.match_method,
    i.matched_contact_field,
    i.match_candidate_count,
    i.person_id,
    i.account_id,
    i.account_number,
    c.primary_person_name as customer_name,
    c.account_status,
    c.current_balance,
    c.past_due_amount,
    c.full_service_address,
    c.open_field_activity_count,
    c.lead_status,

    -- Lineage
    'genesys_cloud' as source_system,
    'genesys:interaction:' || i.interaction_id as source_reference,
    i.data_classification,
    i.synced_at
from interactions as i
left join {{ ref('int_customer__account_360') }} as c
    on i.account_id = c.account_id
