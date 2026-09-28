-- AI-facing customer context: one row per CC&B account.
-- Hybrid shape: structured columns for the Agent Assist UI, plus the Autotask-style
-- OKF contract (id / title / url / content). url is null: the POC has no genuine
-- CC&B deep link, and a made-up one must not be presented as a citation.
-- source_reference is the non-URL lineage key.
{% set frontmatter = [
    "'account_id: ' || " ~ yaml_value('account_id'),
    "'account_number: ' || " ~ yaml_value('account_number'),
    "'account_status: ' || " ~ yaml_value('account_status'),
    "'account_type: ' || " ~ yaml_value('account_type'),
    "'primary_customer: ' || " ~ yaml_value('primary_person_name'),
    "'service_address: ' || " ~ yaml_value('full_service_address'),
    "'current_balance: ' || " ~ yaml_value(md_money('current_balance')),
    "'past_due_amount: ' || " ~ yaml_value(md_money('past_due_amount')),
    "'source_system: oracle_ccb'",
    "'source_reference: ' || " ~ yaml_value('source_reference'),
    "'data_classification: ' || " ~ yaml_value('data_classification'),
] %}

{% set body = [
    "'# Account Overview'", "''",
    md_line('Account number', 'account_number'),
    md_line('Status', 'account_status'),
    md_line('Type', 'account_type'),
    md_line('Billing cycle', 'billing_cycle'),
    md_line('Account opened', format_ts('account_created_date')),
    md_line('Autopay', md_yes_no('is_autopay_enabled')),
    md_line('Paperless billing', md_yes_no('is_paperless_billing')),
    "''",
    "'# Customer'", "''",
    md_line('Primary customer', "primary_person_name || coalesce(' (' || primary_relationship_type || ')', '')"),
    md_line('Phone', 'primary_phone'),
    md_line('Alternate phone', 'primary_alternate_phone'),
    md_line('Email', 'primary_email'),
    md_line('Preferred contact method', 'preferred_contact_method'),
    md_line('People on account', 'linked_persons_summary'),
    "''",
    "'# Service and Meter'", "''",
    md_line('Service address', 'full_service_address'),
    md_line('Premise', "premise_number || coalesce(' (' || property_type || ', ' || premise_service_status || ')', '')"),
    md_line('Service district', 'service_district'),
    md_line('Service point', "service_point_type || coalesce(' - ' || service_point_status, '') || coalesce(', tap ' || tap_number, '')"),
    md_line('Meter', "meter_number || coalesce(' (' || meter_size || ' ' || meter_type || ', ' || meter_status || ')', '')"),
    md_line('Meter location', 'meter_location'),
    md_line('Meter last tested', format_ts('meter_last_test_date')),
    "''",
    "'# Billing'", "''",
    md_line('Current balance', md_money('current_balance')),
    md_line('Past due amount', md_money('past_due_amount')),
    md_line('Open bills', "cast(open_bill_count as varchar) || ' totaling ' || " ~ md_money('open_bill_balance')),
    md_line('Latest bill', md_money('latest_bill_amount') ~ " || ' on ' || " ~ format_ts('latest_bill_date') ~ " || coalesce(' (' || latest_bill_status || ', due ' || " ~ format_ts('latest_bill_due_date') ~ " || ')', '')"),
    md_line('Last payment', md_money('last_payment_amount') ~ " || ' on ' || " ~ format_ts('last_payment_date') ~ " || coalesce(' via ' || last_payment_method, '')"),
    md_line('Billed, last 12 months', md_money('billed_amount_12m')),
    md_line('Paid, last 12 months', md_money('paid_amount_12m')),
    md_line('Average bill, last 12 months', md_money('avg_bill_amount_12m')),
    "''",
    "'# Usage'", "''",
    md_line('Latest period', format_ts('latest_usage_period_start') ~ " || ' to ' || " ~ format_ts('latest_usage_period_end')),
    md_line('Latest usage', "cast(latest_usage_gallons as varchar) || ' gallons' || coalesce(' (' || latest_usage_flag || ', ' || latest_read_type || ')', '')"),
    md_line('12-month average', "cast(avg_usage_gallons_12m as varchar) || ' gallons'"),
    md_line('Latest vs 12-month average', "cast(latest_usage_vs_12m_avg_pct as varchar) || '%'"),
    md_line('High / low usage periods, last 12 months', "cast(high_usage_periods_12m as varchar) || ' high, ' || cast(low_usage_periods_12m as varchar) || ' low'"),
    "''",
    "'# Field Activities'", "''",
    md_line('Open field activities', 'open_field_activity_count'),
    md_line('Earliest scheduled date (open activities)', format_ts('next_scheduled_field_activity_date')),
    "''",
    md_list_or('open_field_activities_md', 'No open field activities.'),
    "''",
    "'# Contact Notes'", "''",
    md_line('Total notes', 'contact_note_count'),
    "''",
    md_list_or('recent_contact_notes_md', 'No contact notes.'),
    "''",
    "'# Service History'", "''",
    md_list_or('recent_service_history_md', 'No service history events.'),
    "''",
    "'# Lead Program'", "''",
    "case when lead_program_id is null then '_No Lead Reduction Program record._' else "
        ~ md_line('Service line material', 'service_line_material') ~ " || chr(10) || "
        ~ md_line('Lead status', 'lead_status') ~ " || chr(10) || "
        ~ md_line('Program status', 'lead_program_status') ~ " || chr(10) || "
        ~ md_line('Replacement required', md_yes_no('is_lead_replacement_required')) ~ " || chr(10) || "
        ~ md_line('Inspection date', format_ts('lead_inspection_date')) ~ " || chr(10) || "
        ~ md_line('Replacement date', format_ts('lead_replacement_date')) ~ " end",
    "''",
    "'# Contact Center History'", "''",
    md_line('Matched Genesys interactions', 'interaction_count'),
    md_line('Last interaction', format_ts('last_interaction_at', 'datetime_minute') ~ " || ' UTC'"),
] %}

with customers as (
    select
        *,
        'ccb:account:' || account_id as source_reference,
        {% if var('poc_synthetic_data') %}'synthetic_poc'{% else %}'production'{% endif %} as data_classification
    from {{ ref('int_customer__account_360') }}
)

select
    -- OKF contract
    account_number as id,
    coalesce(primary_person_name, 'Unknown customer') || ' - Account ' || account_number as title,
    cast(null as varchar) as url,
    '---' || chr(10)
    || {{ frontmatter | join(" || chr(10) || ") }} || chr(10)
    || '---' || chr(10) || chr(10)
    || {{ body | join(" || chr(10) || ") }} as content,

    -- Structured context
    account_id,
    account_number,
    account_status,
    account_type,
    primary_person_id,
    primary_person_name,
    primary_phone,
    primary_email,
    linked_person_count,
    full_service_address,
    premise_id,
    service_point_id,
    meter_id,
    meter_number,
    current_balance,
    past_due_amount,
    is_autopay_enabled,
    latest_bill_id,
    latest_bill_date,
    latest_bill_amount,
    latest_bill_status,
    open_bill_count,
    open_bill_balance,
    last_payment_date,
    last_payment_amount,
    latest_usage_gallons,
    avg_usage_gallons_12m,
    latest_usage_vs_12m_avg_pct,
    latest_usage_flag,
    open_field_activity_count,
    next_scheduled_field_activity_date,
    contact_note_count,
    last_contact_note_date,
    lead_status,
    lead_program_status,
    interaction_count,
    last_interaction_at,

    -- Lineage
    'oracle_ccb' as source_system,
    source_reference,
    data_classification,
    account_synced_at as synced_at
from customers
