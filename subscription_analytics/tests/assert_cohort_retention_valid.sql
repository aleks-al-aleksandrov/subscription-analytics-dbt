-- Sanity check on fct_cohort_retention:
-- 1. One row per cohort_month and months_since_start.
-- 2. Retained subscriptions never exceed the cohort size.
-- 3. Retention never goes up from one month to the next (a cancellation is final).

with retention as (
    select
        *,
        count(*) over (
            partition by cohort_month, months_since_start
        ) as rows_per_key,
        lag(retained_subscriptions) over (
            partition by cohort_month
            order by months_since_start
        ) as previous_retained_subscriptions
    from {{ ref('fct_cohort_retention') }}
)

select
    cohort_month,
    months_since_start,
    cohort_size,
    retained_subscriptions,
    previous_retained_subscriptions
from retention
where rows_per_key > 1
   or retained_subscriptions > cohort_size
   or retained_subscriptions > previous_retained_subscriptions
