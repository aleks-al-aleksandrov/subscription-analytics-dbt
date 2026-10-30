-- Financial reconciliation test:
-- Fails if the total payment amount or transaction count for successful payments
-- in fct_payments diverges from stg_payments.

with stg as (
    select
        count(*) as successful_count,
        coalesce(sum(amount_eur), 0) as total_amount_eur
    from {{ ref('stg_payments') }}
    where is_successful
),

fct as (
    select
        count(*) as successful_count,
        coalesce(sum(amount_eur), 0) as total_amount_eur
    from {{ ref('fct_payments') }}
    where is_successful
)

select
    stg.successful_count as stg_successful_count,
    fct.successful_count as fct_successful_count,
    stg.total_amount_eur as stg_total_amount_eur,
    fct.total_amount_eur as fct_total_amount_eur
from stg
cross join fct
where stg.successful_count != fct.successful_count
   or stg.total_amount_eur != fct.total_amount_eur
