#!/usr/bin/env python3
"""ARCHI W1.6: статична перевірка ізоляції клієнтів у запитах n8n.

Для кожного Postgres-вузла в workflows/*.json, що звертається до таблиць/в'ю Archi (список TENANT),
перевіряє, що в запиті є `company_id`. Без `--strict` лише друкує базову лінію (код 0);
з `--strict` повертає код 1, якщо є вузли без `company_id` (бранка перед підключенням першого клієнта).
Це лише статична частина тесту ізоляції (docs/W1_DESIGN.md §6); динамічну частину (дві тестові компанії) виконує SQL-тест.
"""
import json, re, sys, glob, os

TENANT = ["project_metrics","time_log","money_log","payment_schedule","meeting_log","kp_log","rates",
          "wr_weekly_snapshots","wr_plan_items","archi_wr_inbox","archi_thresholds",
          "evm_packages","evm_package_done","archi_report_today","archi_snapshot_history",
          "archi_weekly_progress","archi_plan_execution","evm_classic_today"]
root = os.path.join(os.path.dirname(__file__), "..")
strict = "--strict" in sys.argv
bad_total = 0
for p in sorted(glob.glob(os.path.join(root, "workflows", "*.json"))):
    d = json.load(open(p)); w = d.get("workflow", d)
    pg = [n for n in w["nodes"] if n["type"].endswith("postgres")]
    touch = bad = 0
    miss = []
    for n in pg:
        q = str(n["parameters"].get("query", ""))
        qs = re.sub(r"'[^']*'", "''", q)  # літерали рядків не рахуються (напр. mode='meeting_log')
        if not any(re.search(r"\b" + t + r"\b", qs) for t in TENANT):
            continue
        touch += 1
        if "company_id" not in q and "company_id" not in json.dumps(n["parameters"].get("options", {})):
            bad += 1; miss.append(n["name"])
    bad_total += bad
    print(f"{os.path.basename(p)}: Postgres-вузлів {len(pg)}, з таблицями Archi {touch}, без company_id {bad}")
    if bad and "-v" in sys.argv:
        for m in miss: print("   -", m)
print(f"Разом без company_id: {bad_total}")
sys.exit(1 if (strict and bad_total) else 0)
