with source as (
    select *
    from {{ source('raw', 'payments') }}
),

ranked as (
    select
        *,
        row_number() over (
            partition by payment_id
            order by created_at desc
        ) as row_num
    from source
),

cleaned as (
    select
        payment_id,
        subscription_id,
        customer_id,
        cast(payment_date as date) as payment_date,
        cast(amount_eur as decimal(10, 2)) as amount_eur,
        currency,
        status,
        (status = 'succeeded') as is_successful,
        (cast(created_at as date) > cast(payment_date as date)) as is_late_arrival,
        cast(created_at as timestamp) as created_at
    from ranked
    where row_num = 1
)

select *
from cleaned
