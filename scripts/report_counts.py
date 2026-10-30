"""Post-pipeline data verification gate.

Connects to DuckDB in read-only mode, reports key row counts across layers,
and exits with status 1 if fct_payments and stg_payments do not match.
"""
import os
import sys
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
DB_PATH = Path(
    os.environ.get(
        "DUCKDB_PATH",
        ROOT / "subscription_analytics" / "subscription.duckdb",
    )
)


def main():
    con = duckdb.connect(str(DB_PATH), read_only=True)
    try:
        raw_payments = con.execute("select count(*) from raw.payments").fetchone()[0]
        stg_payments = con.execute("select count(*) from main.stg_payments").fetchone()[0]
        fct_payments = con.execute("select count(*) from main.fct_payments").fetchone()[0]
        snap_total, snap_closed = con.execute(
            "select count(*), count(*) filter (where dbt_valid_to is not null) "
            "from snapshots.subs_snapshot"
        ).fetchone()
    finally:
        con.close()

    print(f"raw.payments:           {raw_payments} rows")
    print(f"main.stg_payments:      {stg_payments} rows")
    print(f"main.fct_payments:      {fct_payments} rows")
    print(f"snapshots.subs_snapshot: {snap_total} rows ({snap_closed} closed versions)")

    if fct_payments != stg_payments:
        print(
            f"ERROR: Row count mismatch! fct_payments ({fct_payments}) != stg_payments ({stg_payments})",
            file=sys.stderr,
        )
        sys.exit(1)

    print("OK: fct_payments row count matches stg_payments.")


if __name__ == "__main__":
    main()
