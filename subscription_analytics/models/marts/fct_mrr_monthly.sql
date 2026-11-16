with subscriptions as (
    select *
    from {{ ref('fct_subscriptions') }}
),

months as (
    select *
    from {{ ref('int_months') }}
),

plan_history as (
    select *
    from {{ ref('int_subscription_plan_history') }}
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
                        then plan_history.monthly_value_eur
                        else 0
                    end
                ),
                0
            ) as decimal(12, 2)
        ) as mrr_eur
    from months
    cross join subscriptions
    -- at most one plan version is valid at a month end, so this join cannot fan out
    left join plan_history
        on subscriptions.subscription_id = plan_history.subscription_id
        and plan_history.valid_from_date <= months.month_end_date
        and (plan_history.valid_to_date is null or plan_history.valid_to_date > months.month_end_date)
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
        cast(mrr_eur * 12 as decimal(12, 2)) as arr_eur,
        cast(
            churned_subscriptions * 1.0
            / nullif(lag(active_subscriptions) over (order by month_start_date), 0)
            as decimal(6, 4)
        ) as subscription_churn_rate
    from monthly_summary
)

select *
from final
order by month_start_date
