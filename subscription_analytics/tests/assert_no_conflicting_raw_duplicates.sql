-- Fails if duplicate primary keys in raw.payments or raw.customers have conflicting
-- cleaned business attributes (which would mean row_number() deduplication silently
-- drops a diverging value).

with conflicting_payments as (
    select
        'raw.payments' as source_table,
        payment_id as record_id
    from {{ source('raw', 'payments') }}
    group by payment_id
    having count(distinct subscription_id) > 1
        or count(distinct customer_id) > 1
        or count(distinct cast(payment_date as date)) > 1
        or count(distinct cast(amount_eur as decimal(10, 2))) > 1
        or count(distinct currency) > 1
        or count(distinct status) > 1
),

conflicting_customers as (
    select
        'raw.customers' as source_table,
        customer_id as record_id
    from {{ source('raw', 'customers') }}
    group by customer_id
    having count(distinct coalesce(lower(trim(email)), '')) > 1
        or count(distinct coalesce(upper(trim(country)), '')) > 1
        or count(distinct segment) > 1
        or count(distinct cast(signup_date as date)) > 1
)

select * from conflicting_payments
union all
select * from conflicting_customers
