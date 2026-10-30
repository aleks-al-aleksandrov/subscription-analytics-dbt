{% snapshot subs_snapshot %}

{{
    config(
        target_schema='snapshots',
        unique_key='subscription_id',
        strategy='timestamp',
        updated_at='updated_at'
    )
}}

select
    subscription_id,
    customer_id,
    plan_id,
    status,
    is_active,
    started_date,
    canceled_date,
    updated_at
from {{ ref('stg_subscriptions') }}

{% endsnapshot %}

