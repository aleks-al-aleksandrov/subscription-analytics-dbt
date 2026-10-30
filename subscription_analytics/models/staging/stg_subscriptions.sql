with source as (
    select *
    from {{ source('raw', 'subscriptions') }}
),

cleaned as (
    select
        subscription_id,
        customer_id,
        plan_id,
        status,
        (status = 'active') as is_active,
        cast(started_at as date) as started_date,
        cast(nullif(trim(cast(canceled_at as varchar)), '') as date) as canceled_date,
        cast(updated_at as timestamp) as updated_at
    from source
)

select *
from cleaned
