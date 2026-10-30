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
marts (tables)                models/marts   (in progress)
  dim_customer, dim_plan, fct_subscriptions, fct_payments
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

## Known limitations

- The data is synthetic, so it only reflects the scenarios built into the generator.
- I started with BigQuery, but the free sandbox doesn't allow DML (MERGE, INSERT, UPDATE). Incremental models and snapshots need that, so I moved to DuckDB.
- `stg_subscriptions` only knows the current plan. To get plan history I need a snapshot (SCD type 2) across two data loads.
- If two duplicate rows have different values (for example a different amount), deduplication just picks one and nobody notices. I plan to add a test that catches conflicting duplicates in raw.
