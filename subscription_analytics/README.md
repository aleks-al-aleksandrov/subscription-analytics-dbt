# subscription_analytics (dbt project)

This folder contains the dbt project. See the root [`README.md`](../README.md) for the full architecture, metric definitions, design trade-offs, and lineage graph.

## Structure

- `models/staging/`: Views (`stg_customers`, `stg_plans`, `stg_subscriptions`, `stg_payments`), source definitions (`_sources.yml`), and staging schema tests (`_staging.yml`).
- `snapshots/`: SCD Type 2 snapshot (`subs_snapshot.sql`) and snapshot schema tests (`_snapshots.yml`).
- `models/marts/`: Dimension, fact, and metric models (`dim_customer`, `dim_plan`, `fct_subscriptions`, incremental `fct_payments`, `fct_mrr_monthly`) and schema tests (`_marts.yml`).
- `tests/`: Singular SQL tests for business logic, raw duplicate conflict detection, MRR sanity, and financial reconciliation.

## Running Commands

From inside `subscription_analytics/` (with `.venv` activated and raw data loaded):

```powershell
dbt debug --profiles-dir .
dbt build --profiles-dir .
dbt docs generate --profiles-dir .
dbt docs serve --profiles-dir .
```
