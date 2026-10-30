with customers as (
    select *
    from {{ ref('stg_customers') }}
),

subscriptions as (
    select *
    from {{ ref('stg_subscriptions') }}
),

active_subscriptions as (
    select
        customer_id,
        bool_or(is_active) as has_active_subscription
    from subscriptions
    group by customer_id
),

final as (
    select
        customers.customer_id,
        customers.email,
        customers.country,
        customers.segment,
        customers.signup_date,
        customers.created_at,
        customers.updated_at,
        coalesce(active_subscriptions.has_active_subscription, false) as is_active_customer
    from customers
    left join active_subscriptions
        on customers.customer_id = active_subscriptions.customer_id
)

select *
from final
