with subscriptions as (
    select *
    from {{ ref('fct_subscriptions') }}
),

months as (
    select *
    from {{ ref('int_months') }}
),

cohorts as (
    select
        subscription_id,
        canceled_date,
        cast(date_trunc('month', started_date) as date) as cohort_month
    from subscriptions
),

cohort_months as (
    select
        cohorts.cohort_month,
        datediff('month', cohorts.cohort_month, months.month_start_date) as months_since_start,
        cohorts.subscription_id,
        (cohorts.canceled_date is null or cohorts.canceled_date > months.month_end_date) as is_retained
    from cohorts
    inner join months
        on months.month_start_date >= cohorts.cohort_month
),

final as (
    select
        cohort_month,
        months_since_start,
        count(*) as cohort_size,
        count(case when is_retained then subscription_id end) as retained_subscriptions,
        cast(
            count(case when is_retained then subscription_id end) * 1.0 / count(*)
            as decimal(6, 4)
        ) as retention_rate
    from cohort_months
    group by
        cohort_month,
        months_since_start
)

select *
from final
order by
    cohort_month,
    months_since_start
