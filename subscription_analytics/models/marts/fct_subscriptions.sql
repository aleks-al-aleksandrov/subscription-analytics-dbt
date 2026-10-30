with subscriptions as (
    select *
    from {{ ref('stg_subscriptions') }}
),

plans as (
    select *
    from {{ ref('dim_plan') }}
),

data_watermark as (
    select max(cast(updated_at as date)) as as_of_date
    from subscriptions
),

final as (
    select
        subscriptions.subscription_id,
        subscriptions.customer_id,
        subscriptions.plan_id,
        subscriptions.status,
        subscriptions.is_active,
        subscriptions.started_date,
        subscriptions.canceled_date,
        subscriptions.updated_at,
        plans.monthly_price_eur as monthly_value_eur,
        datediff(
            'day',
            subscriptions.started_date,
            coalesce(subscriptions.canceled_date, data_watermark.as_of_date)
        ) as tenure_days
    from subscriptions
    left join plans
        on subscriptions.plan_id = plans.plan_id
    cross join data_watermark
)

select *
from final
