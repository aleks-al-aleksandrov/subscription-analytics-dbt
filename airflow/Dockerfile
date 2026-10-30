FROM astrocrpublic.azurecr.io/runtime:3.3-11

ENV DUCKDB_PATH=/usr/local/airflow/duckdb_data/subscription.duckdb
RUN mkdir -p /usr/local/airflow/duckdb_data
RUN python -m venv /usr/local/airflow/dbt_venv && \
    /usr/local/airflow/dbt_venv/bin/pip install --no-cache-dir dbt-core==1.12.6 dbt-duckdb==1.11.1
