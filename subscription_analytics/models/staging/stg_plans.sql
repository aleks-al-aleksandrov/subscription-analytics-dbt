with source as (
    select *
    from {{ source('raw', 'plans') }}
),

renamed as (
    select
        plan_id,
        plan_name,
        billing_period,
        cast(price_eur as decimal(10, 2)) as price_eur
    from source
)

select *
from renamed
