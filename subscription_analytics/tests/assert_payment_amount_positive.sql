-- Fails if any payment has a zero or negative amount.
select
    payment_id,
    amount_eur
from {{ ref('stg_payments') }}
where amount_eur <= 0
