with subscriptions as (
    select *
    from {{ ref('fct_subscriptions') }}
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
),

monthly_summary as (
    select
        months.month_start_date,
        months.month_end_date,
        count(
            case
                when subscriptions.started_date <= months.month_end_date
                 and (subscriptions.canceled_date is null or subscriptions.canceled_date > months.month_end_date)
                then subscriptions.subscription_id
            end
        ) as active_subscriptions,
        count(
            distinct case
                when subscriptions.started_date <= months.month_end_date
                 and (subscriptions.canceled_date is null or subscriptions.canceled_date > months.month_end_date)
                then subscriptions.customer_id
            end
        ) as active_customers,
        count(
            case
                when subscriptions.started_date between months.month_start_date and months.month_end_date
                then subscriptions.subscription_id
            end
        ) as new_subscriptions,
        count(
            case
                when subscriptions.canceled_date between months.month_start_date and months.month_end_date
                then subscriptions.subscription_id
            end
        ) as churned_subscriptions,
        cast(
            coalesce(
                sum(
                    case
                        when subscriptions.started_date <= months.month_end_date
                         and (subscriptions.canceled_date is null or subscriptions.canceled_date > months.month_end_date)
                        then subscriptions.monthly_value_eur
                        else 0
                    end
                ),
                0
            ) as decimal(12, 2)
        ) as mrr_eur
    from months
    cross join subscriptions
    group by
        months.month_start_date,
        months.month_end_date
),

final as (
    select
        month_start_date,
        month_end_date,
        active_subscriptions,
        active_customers,
        new_subscriptions,
        churned_subscriptions,
        mrr_eur,
        cast(mrr_eur * 12 as decimal(12, 2)) as arr_eur
    from monthly_summary
)

select *
from final
order by month_start_date
