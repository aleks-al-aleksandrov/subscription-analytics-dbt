-- Fails if fct_payments.current_plan_id differs from the subscription's plan in
-- stg_subscriptions (an incremental run left old payment rows with a stale plan).
select
    payments.payment_id,
    payments.subscription_id,
    payments.current_plan_id,
    subscriptions.plan_id as subscription_plan_id
from {{ ref('fct_payments') }} as payments
inner join {{ ref('stg_subscriptions') }} as subscriptions
    on payments.subscription_id = subscriptions.subscription_id
where payments.current_plan_id != subscriptions.plan_id
