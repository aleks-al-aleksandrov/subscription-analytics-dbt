"""Synthetic subscription data generator.

Run it twice to simulate two loads of the source system:
    python scripts/generate_data.py --as-of 2026-06-30
    python scripts/generate_data.py --as-of 2026-09-30
"""
import argparse
import csv
import random
from datetime import date, datetime, time, timedelta
from pathlib import Path

SEED = 42
N_CUSTOMERS = 2000
WORLD_START = date(2025, 1, 1)
WORLD_END = date(2026, 9, 30)

PLANS = [
    # plan_id, plan_name, billing_period, price_eur
    ("basic_m", "Basic", "monthly", 9.00),
    ("standard_m", "Standard", "monthly", 19.00),
    ("premium_m", "Premium", "monthly", 39.00),
    ("standard_a", "Standard Annual", "annual", 190.00),
]
PLAN_BY_ID = {p[0]: p for p in PLANS}
PLAN_IDS = [p[0] for p in PLANS]
COUNTRIES = ["BG", "DE", "GB", "FR", "RO", "ES", "NL"]
OUT_DIR = Path(__file__).resolve().parents[1] / "data" / "raw"


def add_months(d, months):
    total = d.year * 12 + (d.month - 1) + months
    year, month = divmod(total, 12)
    month += 1
    day = d.day
    while True:
        try:
            return date(year, month, day)
        except ValueError:
            day -= 1


def plan_at(events, d):
    current = events[0][1]
    for ev_date, plan_id in events:
        if ev_date <= d:
            current = plan_id
    return current


def build_world():
    """Build the full history once; each run then filters it by --as-of."""
    rng = random.Random(SEED)
    customers, subs, payments = [], [], []
    pay_seq = 0
    span = (WORLD_END - WORLD_START).days

    for i in range(1, N_CUSTOMERS + 1):
        cid = f"cus_{i:05d}"
        sid = f"sub_{i:05d}"
        start = WORLD_START + timedelta(days=int(rng.random() ** 1.2 * (span - 20)))
        segment = rng.choices(["B2C", "B2B"], [0.8, 0.2])[0]
        first_plan = rng.choices(PLAN_IDS, [0.4, 0.3, 0.1, 0.2])[0]
        events = [(start, first_plan)]

        change_date = None
        if rng.random() < 0.15:
            change_date = start + timedelta(days=rng.randint(60, 400))
            new_plan = rng.choice([p for p in PLAN_IDS if p != first_plan])
        cancel_date = None
        if rng.random() < 0.20:
            cancel_date = start + timedelta(days=rng.randint(30, 450))
        if change_date and cancel_date and cancel_date <= change_date:
            change_date = None
        if change_date:
            events.append((change_date, new_plan))

        # Customer row, with deliberately messy values
        base_email = f"customer_{i:05d}@example.com"
        email = base_email
        r = rng.random()
        if r < 0.02:
            email = ""
        elif r < 0.05:
            email = base_email.upper()

        clean_country = rng.choice(COUNTRIES)
        country = clean_country
        r = rng.random()
        if r < 0.04:
            country = clean_country.lower()
        elif r < 0.07:
            country = f" {clean_country} "

        created_at = datetime.combine(start, time(rng.randint(8, 20), rng.randint(0, 59)))
        row = {
            "customer_id": cid,
            "email": email,
            "country": country,
            "segment": segment,
            "signup_date": start,
            "created_at": created_at,
            "updated_at": created_at,
        }
        customers.append(row)
        if rng.random() < 0.01:  # duplicate customer row with a later update
            customers.append({
                **row,
                "country": clean_country,
                "updated_at": created_at + timedelta(days=rng.randint(1, 30)),
            })

        subs.append({
            "subscription_id": sid,
            "customer_id": cid,
            "start": start,
            "events": events,
            "cancel_date": cancel_date,
        })

        # Payments
        k = 0
        pay_date = start
        while pay_date <= WORLD_END and (cancel_date is None or pay_date < cancel_date):
            plan = PLAN_BY_ID[plan_at(events, pay_date)]
            pay_seq += 1
            lag = rng.randint(3, 6) if rng.random() < 0.02 else 0  # late arrivals
            created = datetime.combine(
                pay_date, time(rng.randint(0, 23), rng.randint(0, 59))
            ) + timedelta(days=lag)
            prow = {
                "payment_id": f"pay_{pay_seq:07d}",
                "subscription_id": sid,
                "customer_id": cid,
                "payment_date": pay_date,
                "amount_eur": plan[3],
                "currency": "EUR",
                "status": rng.choices(["succeeded", "failed"], [0.97, 0.03])[0],
                "created_at": created,
            }
            payments.append(prow)
            if rng.random() < 0.01:  # exact duplicate row
                payments.append(dict(prow))
            k += 12 if plan[2] == "annual" else 1
            pay_date = add_months(start, k)

    return customers, subs, payments


def write_csv(name, rows, fields):
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    path = OUT_DIR / f"{name}.csv"
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        for r in rows:
            out = {}
            for key in fields:
                v = r[key]
                if isinstance(v, datetime):
                    v = v.isoformat(sep=" ")
                elif isinstance(v, date):
                    v = v.isoformat()
                out[key] = v
            w.writerow(out)
    print(f"{name}: {len(rows)} rows -> {path}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--as-of", required=True, help="YYYY-MM-DD, state of the source system")
    args = parser.parse_args()
    as_of = date.fromisoformat(args.as_of)
    as_of_end = datetime.combine(as_of, time(23, 59, 59))

    customers, subs, payments = build_world()
    customers = [c for c in customers if c["updated_at"] <= as_of_end]
    payments = [p for p in payments if p["created_at"] <= as_of_end]

    subscriptions = []
    for s in subs:
        if s["start"] > as_of:
            continue
        canceled = s["cancel_date"] is not None and s["cancel_date"] <= as_of
        changes = [d for d, _ in s["events"][1:] if d <= as_of]
        last_change = max([s["start"]] + changes + ([s["cancel_date"]] if canceled else []))
        subscriptions.append({
            "subscription_id": s["subscription_id"],
            "customer_id": s["customer_id"],
            "plan_id": plan_at(s["events"], as_of),
            "status": "canceled" if canceled else "active",
            "started_at": s["start"],
            "canceled_at": s["cancel_date"] if canceled else "",
            "updated_at": datetime.combine(last_change, time(0, 0)),
        })

    plans = [
        {"plan_id": p[0], "plan_name": p[1], "billing_period": p[2], "price_eur": p[3]}
        for p in PLANS
    ]

    write_csv("customers", customers,
              ["customer_id", "email", "country", "segment", "signup_date", "created_at", "updated_at"])
    write_csv("plans", plans, ["plan_id", "plan_name", "billing_period", "price_eur"])
    write_csv("subscriptions", subscriptions,
              ["subscription_id", "customer_id", "plan_id", "status", "started_at", "canceled_at", "updated_at"])
    write_csv("payments", payments,
              ["payment_id", "subscription_id", "customer_id", "payment_date", "amount_eur",
               "currency", "status", "created_at"])


if __name__ == "__main__":
    main()
