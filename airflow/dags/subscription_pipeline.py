from datetime import datetime, timedelta
from airflow.sdk import DAG
from airflow.providers.standard.operators.bash import BashOperator

PROJECT = "/usr/local/airflow/project"
PY = "/usr/local/airflow/dbt_venv/bin/python"
DBT = "/usr/local/airflow/dbt_venv/bin/dbt"

with DAG(
    dag_id="subscription_pipeline",
    schedule=None,
    start_date=datetime(2026, 1, 1),
    catchup=False,
    max_active_runs=1,
    params={"as_of": "2026-06-30"},
    default_args={"retries": 2, "retry_delay": timedelta(minutes=1)},
    tags=["dbt", "duckdb"],
) as dag:
    generate_data = BashOperator(
        task_id="generate_data",
        bash_command=f"cd {PROJECT} && {PY} scripts/generate_data.py --as-of " + "{{ params.as_of }}",
    )
    load_raw = BashOperator(
        task_id="load_raw",
        bash_command=f"cd {PROJECT} && {PY} scripts/load_raw.py",
    )
    dbt_build = BashOperator(
        task_id="dbt_build",
        bash_command=f"cd {PROJECT}/subscription_analytics && {DBT} build --profiles-dir .",
    )
    report_counts = BashOperator(
        task_id="report_counts",
        bash_command=f"cd {PROJECT} && {PY} scripts/report_counts.py",
    )

    generate_data >> load_raw >> dbt_build >> report_counts
