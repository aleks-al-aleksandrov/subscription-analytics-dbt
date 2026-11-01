# Airflow Orchestration

This directory contains the Astro CLI project configuration and Directed Acyclic Graphs (DAGs) for orchestrating the subscription analytics pipeline.

## Overview

The primary pipeline DAG is [`dags/subscription_pipeline.py`](dags/subscription_pipeline.py), which coordinates:
1. **`generate_data`**: Synthetic subscription and payment event generation for a given cutoff date (`as_of`).
2. **`load_raw`**: Ingestion of generated CSV batches into DuckDB raw tables.
3. **`dbt_build`**: Running staging models, snapshots (SCD Type 2), mart models (including incremental tables), and tests.
4. **`report_counts`**: Automated row count reconciliation and assertion checks.

For full setup instructions, architecture diagrams, and commands to run locally with Docker / Astro CLI, see the [Orchestration with Airflow](../README.md#orchestration-with-airflow) section in the root README.
