-- Sanity check on fct_mrr_monthly:
-- 1. MRR must never be negative or null.
-- 2. Every calendar month within the dataset window must have active subscriptions (> 0),
--    preventing an empty/unloaded month from displaying as a misleading 0 EUR MRR.

select
    month_start_date,
    month_end_date,
    active_subscriptions,
    mrr_eur
from {{ ref('fct_mrr_monthly') }}
where mrr_eur is null
   or mrr_eur <= 0
   or active_subscriptions <= 0
