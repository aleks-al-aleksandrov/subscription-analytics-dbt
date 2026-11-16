-- Reconciliation between two independent calculations of today's MRR:
-- the latest month in fct_mrr_monthly (plan taken from the snapshot history)
-- must equal the sum over currently active rows in fct_subscriptions.
-- A subscription missing from the plan history would show up here as a gap.

with latest_month as (
    select mrr_eur
    from {{ ref('fct_mrr_monthly') }}
    order by month_start_date desc
    limit 1
),

current_subscriptions as (
    select coalesce(sum(monthly_value_eur), 0) as mrr_eur
    from {{ ref('fct_subscriptions') }}
    where is_active
)

select
    latest_month.mrr_eur as mrr_monthly_eur,
    current_subscriptions.mrr_eur as subscriptions_mrr_eur
from latest_month
cross join current_subscriptions
where latest_month.mrr_eur != current_subscriptions.mrr_eur
