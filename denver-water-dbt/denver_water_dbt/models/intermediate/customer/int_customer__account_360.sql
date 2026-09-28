-- One row per account: the full customer context assembled from the account,
-- its people, service, billing, usage, activity and matched Genesys interactions.
with primary_person as (
    select *
    from {{ ref('int_customer__person_accounts') }}
    where is_primary
    qualify row_number() over (
        partition by account_id
        order by relationship_start_date desc, person_id
    ) = 1
),

linked_persons as (
    select
        account_id,
        count(*) as linked_person_count,
        {{ string_agg_ordered(
            "full_name || ' (' || relationship_type || case when is_primary then ', primary' else '' end || ')'",
            "case when is_primary then 0 else 1 end, full_name",
            'semicolon'
        ) }} as linked_persons_summary
    from {{ ref('int_customer__person_accounts') }}
    group by account_id
),

interaction_stats as (
    select
        m.account_id,
        count(*) as interaction_count,
        max(i.started_at) as last_interaction_at
    from {{ ref('int_interactions__customer_match') }} as m
    inner join {{ ref('stg_genesys__interactions') }} as i
        on m.interaction_id = i.interaction_id
    where m.account_id is not null
    group by m.account_id
)

select
    a.account_id,
    a.account_number,
    a.account_type,
    a.account_status,
    a.billing_cycle,
    a.current_balance,
    a.past_due_amount,
    a.is_autopay_enabled,
    a.is_paperless_billing,
    a.account_created_date,

    pp.person_id as primary_person_id,
    pp.full_name as primary_person_name,
    pp.relationship_type as primary_relationship_type,
    pp.phone as primary_phone,
    pp.alternate_phone as primary_alternate_phone,
    pp.email as primary_email,
    pp.preferred_contact_method,
    coalesce(lp.linked_person_count, 0) as linked_person_count,
    lp.linked_persons_summary,

    svc.premise_id,
    svc.premise_number,
    svc.premise_count,
    svc.full_service_address,
    svc.service_address,
    svc.service_city,
    svc.service_state,
    svc.service_zip_code,
    svc.property_type,
    svc.service_district,
    svc.premise_service_status,
    svc.service_point_id,
    svc.service_point_type,
    svc.service_point_status,
    svc.tap_number,
    svc.meter_id,
    svc.meter_number,
    svc.meter_size,
    svc.meter_type,
    svc.meter_location,
    svc.meter_status,
    svc.meter_install_date,
    svc.meter_last_test_date,
    svc.lead_program_id,
    svc.service_line_material,
    svc.lead_status,
    svc.lead_program_status,
    svc.is_lead_replacement_required,
    svc.lead_inspection_date,
    svc.lead_replacement_date,

    bil.latest_bill_id,
    bil.latest_bill_date,
    bil.latest_bill_due_date,
    bil.latest_billing_period_start,
    bil.latest_billing_period_end,
    bil.latest_bill_amount,
    bil.latest_bill_remaining_balance,
    bil.latest_bill_status,
    bil.bill_count,
    bil.open_bill_count,
    bil.open_bill_balance,
    bil.billed_amount_12m,
    bil.avg_bill_amount_12m,
    bil.last_payment_id,
    bil.last_payment_date,
    bil.last_payment_amount,
    bil.last_payment_method,
    bil.last_payment_status,
    bil.last_payment_confirmation_number,
    bil.payment_count,
    bil.paid_amount_12m,

    usg.latest_consumption_id,
    usg.latest_usage_period_start,
    usg.latest_usage_period_end,
    usg.latest_usage_gallons,
    usg.latest_meter_read,
    usg.latest_read_type,
    usg.latest_usage_flag,
    usg.usage_period_count,
    usg.avg_usage_gallons_12m,
    usg.latest_usage_vs_12m_avg_pct,
    usg.high_usage_periods_12m,
    usg.low_usage_periods_12m,

    act.field_activity_count,
    act.open_field_activity_count,
    act.next_scheduled_field_activity_date,
    act.last_completed_field_activity_date,
    act.open_field_activities_md,
    act.contact_note_count,
    act.last_contact_note_date,
    act.recent_contact_notes_md,
    act.service_history_event_count,
    act.last_service_history_date,
    act.recent_service_history_md,

    coalesce(ist.interaction_count, 0) as interaction_count,
    ist.last_interaction_at,

    a.synced_at as account_synced_at
from {{ ref('stg_ccb__accounts') }} as a
left join primary_person as pp
    on a.account_id = pp.account_id
left join linked_persons as lp
    on a.account_id = lp.account_id
left join {{ ref('int_customer__account_service') }} as svc
    on a.account_id = svc.account_id
left join {{ ref('int_customer__billing_summary') }} as bil
    on a.account_id = bil.account_id
left join {{ ref('int_customer__usage_summary') }} as usg
    on a.account_id = usg.account_id
left join {{ ref('int_customer__activity_summary') }} as act
    on a.account_id = act.account_id
left join interaction_stats as ist
    on a.account_id = ist.account_id
