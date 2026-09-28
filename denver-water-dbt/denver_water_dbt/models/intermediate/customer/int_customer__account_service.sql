-- One row per account: its service premise, service point, meter and Lead
-- Reduction Program status. Premise -> account is 1:1 in the POC data, but an
-- account could have several premises, so one is picked (active first).
with premises as (
    select
        *,
        count(*) over (partition by account_id) as premise_count
    from {{ ref('stg_ccb__premises') }}
    qualify row_number() over (
        partition by account_id
        order by case when service_status = 'Active' then 0 else 1 end, premise_id
    ) = 1
),

service_points as (
    select *
    from {{ ref('stg_ccb__service_points') }}
    qualify row_number() over (
        partition by premise_id
        order by case when service_status = 'Active' then 0 else 1 end, service_point_id
    ) = 1
),

meters as (
    select *
    from {{ ref('stg_ccb__meters') }}
    qualify row_number() over (
        partition by service_point_id
        order by case when meter_status = 'Active' then 0 else 1 end, install_date desc, meter_id
    ) = 1
),

lead_program as (
    select *
    from {{ ref('stg_ccb__lead_program') }}
    qualify row_number() over (
        partition by premise_id
        order by inspection_date desc, lead_program_id
    ) = 1
)

select
    a.account_id,
    pr.premise_id,
    pr.premise_number,
    pr.premise_count,
    pr.service_address,
    pr.city as service_city,
    pr.state as service_state,
    pr.zip_code as service_zip_code,
    trim(
        coalesce(pr.service_address, '')
        || coalesce(', ' || pr.city, '')
        || coalesce(', ' || pr.state, '')
        || coalesce(' ' || pr.zip_code, '')
    ) as full_service_address,
    pr.property_type,
    pr.service_district,
    pr.service_status as premise_service_status,
    sp.service_point_id,
    sp.service_point_type,
    sp.service_status as service_point_status,
    sp.tap_number,
    m.meter_id,
    m.meter_number,
    m.meter_size,
    m.meter_type,
    m.meter_location,
    m.meter_status,
    m.install_date as meter_install_date,
    m.last_test_date as meter_last_test_date,
    lp.lead_program_id,
    lp.service_line_material,
    lp.lead_status,
    lp.program_status as lead_program_status,
    lp.is_replacement_required as is_lead_replacement_required,
    lp.inspection_date as lead_inspection_date,
    lp.replacement_date as lead_replacement_date
from {{ ref('stg_ccb__accounts') }} as a
left join premises as pr
    on a.account_id = pr.account_id
left join service_points as sp
    on pr.premise_id = sp.premise_id
left join meters as m
    on sp.service_point_id = m.service_point_id
left join lead_program as lp
    on pr.premise_id = lp.premise_id
