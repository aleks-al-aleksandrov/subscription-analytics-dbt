# Subscription Analytics (dbt + DuckDB)

## Purpose

I built this project to practise analytics engineering end to end on a realistic problem: a subscription business with customers, plans, subscriptions and payments. The goal is to go from messy raw data to clean, tested models that can answer questions like "what is our MRR?" or "how many customers churned last month?".

## Architecture

```
scripts/generate_data.py      synthetic CSVs  ->  data/raw/*.csv
scripts/load_raw.py           CSVs            ->  DuckDB schema "raw"

raw (tables)
  customers, plans, subscriptions, payments
        |
        v
staging (views)               models/staging
  stg_customers, stg_plans, stg_subscriptions, stg_payments
        |
        v
marts (tables & incremental)  models/marts
  dim_customer, dim_plan, fct_subscriptions, fct_payments (incremental)
```

I keep the layers strict:

- **raw** is a copy of the source and I never change it.
- **staging** has one model per source table. This is where I rename, cast, trim and deduplicate. No joins here.
- **marts** is where staging models get joined into dimensions and facts, each with a clear grain.

## Data

There is no real company behind this, so the project uses a synthetic data generator (`scripts/generate_data.py`). It uses a fixed seed (42), so the output is the same every time. The `--as-of` flag decides what the "source system" looks like on a given day. I load it first with `2026-06-30`, and later with `2026-09-30` to get plan changes and cancellations for the snapshot.

The generator includes the kind of problems expected in real data, so the staging layer has something to do:

- duplicate customer and payment rows
- emails in mixed case, and some empty ones
- country codes in the wrong case or with extra spaces
- around 2% of payments that show up after their payment date

## How to run from scratch

You need Python 3.13. The commands are for Windows PowerShell.

```powershell
git clone <repo-url>
cd subscription-analytics-dbt
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install dbt-core dbt-duckdb

python scripts\generate_data.py --as-of 2026-06-30
python scripts\load_raw.py

cd subscription_analytics
dbt debug --profiles-dir .
dbt build --profiles-dir .
```

`profiles.yml` is inside `subscription_analytics/` and points to the local file `subscription.duckdb`.

## Design decisions

- **DuckDB instead of a cloud warehouse.** It runs locally, costs nothing and supports incremental models and snapshots, which I need later.
- **Staging as views, marts as tables.** Staging is cheap to rebuild and always matches raw. Marts get queried the most, so I store them as tables.
- **Deduplication in staging.** For customers I keep the newest row by `updated_at`. For payments I keep one row per `payment_id`, the one with the latest `created_at`.
- **Flags, not filters.** I add `is_late_arrival` and `is_successful` as columns instead of dropping rows. That way each mart can decide for itself what to exclude.
- **Tests on every layer.** Primary keys get `unique` and `not_null`, foreign keys get `relationships`, categories get `accepted_values`. Business rules that don't fit a generic test (positive amounts, a subscription can't be canceled before it starts) are singular tests in `tests/`.

## Incremental loading (`fct_payments`)

`fct_payments` is configured as an incremental model (`materialized='incremental'`, `unique_key='payment_id'`, `incremental_strategy='delete+insert'`).

```sql
{% if is_incremental() %}
where payment_date >= (
    select max(payment_date) - interval '7 days'
    from {{ this }}
)
{% endif %}
```

### How it runs

1. **Initial run (or `dbt run --select fct_payments --full-refresh`)**: `is_incremental()` evaluates to `false`, so dbt builds `main.fct_payments` from the entire `stg_payments` view (`14,111` rows for `--as-of 2026-06-30`).
2. **Subsequent incremental runs (`dbt run --select fct_payments`)**: `is_incremental()` evaluates to `true`. dbt only reads rows from `stg_payments` whose `payment_date` is within 7 days of the current maximum `payment_date` in `fct_payments`, deletes any matching `payment_id` keys already in the target table, and inserts the refreshed batch.

### Why a 7-day lookback window?

In the source data, around 2% of payments arrive 3–6 days after their `payment_date` (`created_at > payment_date`). Filtering strictly on `payment_date > max(payment_date)` would miss transactions whose `payment_date` falls before the high-water mark but landed in the source system days later. A 7-day lookback window covers the 3–6 day arrival lag while keeping incremental scans small. Because `unique_key='payment_id'` is set, re-reading the last 7 days overwrites existing rows cleanly without creating duplicates.

### Why `delete+insert` instead of `merge`?

- **Adapter compatibility & simplicity**: In DuckDB, `delete+insert` stages the incoming slice in a temporary table, deletes matching `payment_id` rows from the target table in a single vectorized pass, and inserts the staged rows.
- **Trade-offs & risks**:
  - `delete+insert` replaces the entire row for matched keys, which is ideal here because we want the latest state of every column in the lookback window.
  - On cloud warehouses with large clustered tables (like BigQuery or Snowflake), `merge` can sometimes avoid rewriting unchanged columns, whereas `delete+insert` marks deleted rows and appends new micro-partitions.
  - If a payment arrived more than 7 days late, the lookback window would miss it; a periodic `--full-refresh` (or filtering on an ingestion watermark with a lookback) would be needed to catch extreme outliers.

## Known limitations

- The data is synthetic, so it only reflects the scenarios built into the generator.
- I started with BigQuery, but the free sandbox doesn't allow DML (MERGE, INSERT, UPDATE). Incremental models and snapshots need that, so I moved to DuckDB.
- `stg_subscriptions` only knows the current plan. To get plan history I need a snapshot (SCD type 2) across two data loads.
- If two duplicate rows have different values (for example a different amount), deduplication just picks one and nobody notices. I plan to add a test that catches conflicting duplicates in raw.
