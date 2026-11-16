-- Fails if a subscription does not have exactly one current plan version, or if
-- two of its versions start on the same day (overlapping periods would make the
-- MRR join fan out).

select
    subscription_id,
    count(*) as versions,
    count(case when is_current then 1 end) as current_versions,
    count(distinct valid_from_date) as distinct_start_dates
from {{ ref('int_subscription_plan_history') }}
group by subscription_id
having count(case when is_current then 1 end) != 1
    or count(distinct valid_from_date) != count(*)
