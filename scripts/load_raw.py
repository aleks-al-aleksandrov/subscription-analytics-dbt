"""Load the generated CSV files into the DuckDB `raw` schema (the 'EL' of ELT)."""
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
DB_PATH = ROOT / "subscription_analytics" / "subscription.duckdb"
RAW_DIR = ROOT / "data" / "raw"
TABLES = ["customers", "plans", "subscriptions", "payments"]

con = duckdb.connect(str(DB_PATH))
con.execute("create schema if not exists raw")
for table in TABLES:
    csv_path = (RAW_DIR / f"{table}.csv").as_posix()
    con.execute(
        f"create or replace table raw.{table} as "
        f"select * from read_csv_auto('{csv_path}', header = true)"
    )
    n = con.execute(f"select count(*) from raw.{table}").fetchone()[0]
    print(f"raw.{table}: {n} rows")
con.close()
