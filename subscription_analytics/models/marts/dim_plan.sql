with plans as (
    select *
    from {{ ref('stg_plans') }}
),

final as (
    select
        plan_id,
        plan_name,
        billing_period,
        price_eur,
        cast(
            case
                when billing_period = 'annual' then round(price_eur / 12.0, 2)
                else price_eur
            end as decimal(10, 2)
        ) as monthly_price_eur
    from plans
)

select *
from final
