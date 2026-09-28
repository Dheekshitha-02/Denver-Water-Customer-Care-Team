-- One row per account: open field work, recent contact notes and recent service
-- history, with short markdown bullet lists (capped by the context_* vars) that
-- the AI exports reuse.
with field_activities as (
    select
        *,
        row_number() over (
            partition by account_id
            order by coalesce(scheduled_date, created_date) desc, field_activity_id desc
        ) as open_rank
    from {{ ref('stg_ccb__field_activities') }}
    where is_open
),

field_activity_totals as (
    select
        account_id,
        count(*) as field_activity_count,
        count(case when is_open then 1 end) as open_field_activity_count,
        min(case when is_open then scheduled_date end) as next_scheduled_field_activity_date,
        max(completed_date) as last_completed_field_activity_date
    from {{ ref('stg_ccb__field_activities') }}
    group by account_id
),

open_field_activity_list as (
    select
        account_id,
        {{ string_agg_ordered(
            "'- ' || activity_type || ' (' || activity_status
             || coalesce(', ' || priority || ' priority', '')
             || coalesce(', scheduled ' || " ~ format_ts('scheduled_date') ~ ", '')
             || ')'",
            'open_rank',
            'line'
        ) }} as open_field_activities_md
    from field_activities
    where open_rank <= {{ var('context_open_field_activity_limit') }}
    group by account_id
),

contact_notes as (
    select
        n.*,
        u.full_name as author_name,
        row_number() over (
            partition by n.account_id
            order by n.contact_date desc, n.contact_note_id desc
        ) as note_rank
    from {{ ref('stg_ccb__contact_notes') }} as n
    left join {{ ref('stg_genesys__users') }} as u
        on n.created_by_user_id = u.user_id
),

contact_note_totals as (
    select
        account_id,
        count(*) as contact_note_count,
        max(contact_date) as last_contact_note_date
    from contact_notes
    group by account_id
),

recent_contact_note_list as (
    select
        account_id,
        {{ string_agg_ordered(
            "'- ' || " ~ format_ts('contact_date') ~ " || ' - ' || coalesce(subject, contact_type, 'Note')
             || ' (' || coalesce(channel, 'Unknown channel') || coalesce(', ' || author_name, '') || '): '
             || coalesce(note_text, '')",
            'note_rank',
            'line'
        ) }} as recent_contact_notes_md
    from contact_notes
    where note_rank <= {{ var('context_contact_note_limit') }}
    group by account_id
),

service_history as (
    select
        *,
        row_number() over (
            partition by account_id
            order by effective_date desc, service_history_id desc
        ) as history_rank
    from {{ ref('stg_ccb__service_history') }}
),

service_history_totals as (
    select
        account_id,
        count(*) as service_history_event_count,
        max(effective_date) as last_service_history_date
    from service_history
    group by account_id
),

recent_service_history_list as (
    select
        account_id,
        {{ string_agg_ordered(
            "'- ' || " ~ format_ts('effective_date') ~ " || ' - ' || event_type
             || coalesce(': ' || history_notes, '')",
            'history_rank',
            'line'
        ) }} as recent_service_history_md
    from service_history
    where history_rank <= {{ var('context_service_history_limit') }}
    group by account_id
)

select
    a.account_id,
    coalesce(fat.field_activity_count, 0) as field_activity_count,
    coalesce(fat.open_field_activity_count, 0) as open_field_activity_count,
    fat.next_scheduled_field_activity_date,
    fat.last_completed_field_activity_date,
    ofa.open_field_activities_md,
    coalesce(cnt.contact_note_count, 0) as contact_note_count,
    cnt.last_contact_note_date,
    rcn.recent_contact_notes_md,
    coalesce(sht.service_history_event_count, 0) as service_history_event_count,
    sht.last_service_history_date,
    rsh.recent_service_history_md
from {{ ref('stg_ccb__accounts') }} as a
left join field_activity_totals as fat
    on a.account_id = fat.account_id
left join open_field_activity_list as ofa
    on a.account_id = ofa.account_id
left join contact_note_totals as cnt
    on a.account_id = cnt.account_id
left join recent_contact_note_list as rcn
    on a.account_id = rcn.account_id
left join service_history_totals as sht
    on a.account_id = sht.account_id
left join recent_service_history_list as rsh
    on a.account_id = rsh.account_id
