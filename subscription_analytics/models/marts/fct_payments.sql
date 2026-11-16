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
),

subscriptions as (
    select
        subscription_id,
        plan_id,
        updated_at
    from {{ ref('stg_subscriptions') }}
),

{% if is_incremental() %}
watermark as (
    select max(created_at) - interval '7 days' as reload_from
    from {{ this }}
),
{% endif %}

final as (
    select
        payments.payment_id,
        payments.subscription_id,
        payments.customer_id,
        subscriptions.plan_id as current_plan_id,
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
    {% if is_incremental() %}
    cross join watermark
    -- reload rows that landed since the last run (by ingestion time, so any
    -- arrival lag is covered) and rows whose subscription changed, so that
    -- current_plan_id never goes stale
    where payments.created_at >= watermark.reload_from
       or subscriptions.updated_at >= watermark.reload_from
    {% endif %}
)

select *
from final
