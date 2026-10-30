{{
    config(
        materialized='incremental',
        unique_key='payment_id',
        incremental_strategy='delete+insert'
    )
}}

with payments as (
    select *
    from {{ ref('stg_payments') }}
    {% if is_incremental() %}
    where payment_date >= (
        select max(payment_date) - interval '7 days'
        from {{ this }}
    )
    {% endif %}
),

subscriptions as (
    select
        subscription_id,
        plan_id
    from {{ ref('stg_subscriptions') }}
),

final as (
    select
        payments.payment_id,
        payments.subscription_id,
        payments.customer_id,
        subscriptions.plan_id,
        payments.payment_date,
        payments.amount_eur,
        payments.currency,
        payments.status,
        payments.is_successful,
        payments.is_late_arrival,
        payments.created_at
    from payments
    left join subscriptions
        on payments.subscription_id = subscriptions.subscription_id
)

select *
from final
