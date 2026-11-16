with versions as (
    select
        subscription_id,
        plan_id,
        started_date,
        cast(dbt_valid_from as date) as version_from_date,
        cast(dbt_valid_to as date) as version_to_date,
        row_number() over (
            partition by subscription_id
            order by dbt_valid_from
        ) as version_number
    from {{ ref('subs_snapshot') }}
),

plans as (
    select
        plan_id,
        monthly_price_eur
    from {{ ref('dim_plan') }}
),

final as (
    select
        versions.subscription_id,
        versions.plan_id,
        plans.monthly_price_eur as monthly_value_eur,
        -- the snapshot cannot see what happened before its first run, so the
        -- first known version is stretched back to the subscription start
        case
            when versions.version_number = 1 then versions.started_date
            else versions.version_from_date
        end as valid_from_date,
        versions.version_to_date as valid_to_date,
        (versions.version_to_date is null) as is_current
    from versions
    left join plans
        on versions.plan_id = plans.plan_id
)

select *
from final
