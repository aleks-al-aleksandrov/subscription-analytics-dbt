-- Fails if a subscription was canceled before it started.
select
    subscription_id,
    started_date,
    canceled_date
from {{ ref('stg_subscriptions') }}
where canceled_date < started_date
