with subscriptions as (
    select *
    from {{ ref('stg_subscriptions') }}
),

date_bounds as (
    select
        cast(date_trunc('month', min(started_date)) as date) as first_month_start,
        cast(date_trunc('month', max(cast(updated_at as date))) as date) as last_month_start
    from subscriptions
),

months as (
    select
        cast(month_start as date) as month_start_date,
        cast(last_day(cast(month_start as date)) as date) as month_end_date
    from date_bounds,
    unnest(
        generate_series(
            date_bounds.first_month_start,
            date_bounds.last_month_start,
            interval 1 month
        )
    ) as t(month_start)
)

select *
from months
