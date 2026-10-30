# subscription_analytics (dbt project)

This folder is the dbt project. The full overview is in the root `README.md`.

## Purpose

This project turns the raw subscription data in DuckDB into tested staging models. The next step is dimension and fact tables for subscription metrics.

## Architecture

```
source "raw"  ->  models/staging (views)  ->  models/marts (tables)
```

- `models/staging/_sources.yml` declares the raw tables.
- `models/staging/_staging.yml` has descriptions and generic tests for every model and column.
- `tests/` has singular tests for business rules.

## Data

The data comes from `../scripts/generate_data.py` (fixed seed 42). `../scripts/load_raw.py` loads it into the `raw` schema of `subscription.duckdb`.

## How to run from scratch

From the repo root, after the setup in the root `README.md`:

```powershell
.venv\Scripts\Activate.ps1
python scripts\generate_data.py --as-of 2026-06-30
python scripts\load_raw.py

cd subscription_analytics
dbt build --profiles-dir .
dbt docs generate --profiles-dir .
dbt docs serve --profiles-dir .
```

## Design decisions

- Each staging model maps to exactly one source table. It only renames, casts, cleans and deduplicates.
- Staging is built as views and marts as tables. Both are set in `dbt_project.yml`.
- Every model description states its grain, so it's clear what one row means.

## Known limitations

- Synthetic data only.
- Runs on DuckDB, because the BigQuery sandbox blocks the DML (MERGE/INSERT/UPDATE) that incremental models and snapshots need.
