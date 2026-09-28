-- The customer context must contain every staged account exactly once.
select
    (select count(*) from {{ ref('stg_ccb__accounts') }}) as staged_accounts,
    (select count(*) from {{ ref('int_customer__account_360') }}) as account_360_rows
where (select count(*) from {{ ref('stg_ccb__accounts') }})
   != (select count(*) from {{ ref('int_customer__account_360') }})
