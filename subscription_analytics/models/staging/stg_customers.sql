with source as (
    select *
    from {{ source('raw', 'customers') }}
),

ranked as (
    select
        *,
        row_number() over (
            partition by customer_id
            order by updated_at desc
        ) as row_num
    from source
),

cleaned as (
    select
        customer_id,
        nullif(lower(trim(email)), '') as email,
        nullif(upper(trim(country)), '') as country,
        segment,
        cast(signup_date as date) as signup_date,
        cast(created_at as timestamp) as created_at,
        cast(updated_at as timestamp) as updated_at
    from ranked
    where row_num = 1
)

select *
from cleaned
