#!/usr/bin/env python3
"""ARCHI — генерація docs/handover/10_DATABASE_SCHEMA.md зі знімка схеми (stdlib).

Джерело: найновіший sql/schema/schema_dump_*.json (знімок живої БД; запит — sql/schema/dump_query.sql).
Запуск:  python3 scripts/gen_db_schema.py          — перегенерувати документ
         python3 scripts/gen_db_schema.py --check  — код 1, якщо документ не збігається зі знімком (для CI)
Оновити знімок: виконати dump_query.sql у Supabase, зберегти JSON-рядок `j` у новий файл схеми з датою.
"""
import glob
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "handover" / "10_DATABASE_SCHEMA.md"

# призначення, хто пише/читає, клас даних (довідка автора пакета; джерело — TECH_SPEC §3, 03 §4, FORMULAS)
META = {
    "companies": ("клієнти (тенанти); `DEMO` — демо-компанія", "міграції, оператор", "n8n (резолвер)", "службові"),
    "user_access": ("ролі користувачів Telegram у компанії; `operator` ⇔ `company_id IS NULL`", "оператор, міграції", "n8n (резолвер на 4 входах)", "PII: Telegram id"),
    "company_thresholds": ("перевизначення порогів методології по компанії", "оператор", "`archi_rules`, `archi_threshold`", "конфігурація"),
    "archi_thresholds": ("пороги й план бюро за замовчуванням (31 ключ)", "міграції", "`archi_rules`, `archi_threshold`", "конфігурація"),
    "owner_prefs": ("налаштування ранкового брифінгу власника", "оператор (вручну)", "workflow Morning Brief", "PII: Telegram id"),
    "project_metrics": ("один рядок на проєкт: план і розрахункові поля", "план — Кошторис/міграції; розрахунок — лише `archi_recalc`", "усі екрани, чат, брифінг", "фінансові, комерційна таємниця"),
    "wr_weekly_snapshots": ("знімок тижневого звіту ПМа", "потік «Фінал»", "Weekly Render, `archi_report_today`, `archi_snapshot_history`", "ділові тексти ПМа (можливі ПІБ)"),
    "wr_plan_items": ("пункти плану тижня зі статусами й перенесенням", "потік звіту", "`archi_plan_execution`", "ділові тексти ПМа"),
    "archi_wr_inbox": ("черга повідомлень ПМа до «Відправити»", "`WR: Inbox Add`", "`WR: Fetch Inbox`, `WR: Inbox Consume`", "вільний текст, можливі ПІБ"),
    "time_log": ("відпрацьовані години (`confirmed` після «Фінал»)", "імпорт ботом", "`archi_recalc`, P-10", "PII-lite: виконавець, години"),
    "money_log": ("акти, надходження, оплати субпідрядникам", "імпорт ботом (лише ПМ)", "`archi_recalc`", "фінансові"),
    "payment_schedule": ("графік актів і документації", "Кошторис, міграції", "`archi_recalc`, брифінг", "фінансові"),
    "rates": ("ставки по посадах (глобально, W3.6)", "вручну", "F-02, P-10", "фінансові"),
    "meeting_log": ("журнал зустрічей і домовленостей", "бот (режим «Зустріч»)", "чат (Q10), брифінг", "вільний текст"),
    "kp_log": ("облік комерційних пропозицій", "бот `КП: N`", "Owner View", "комерційні"),
    "archi_bot_mode_state": ("режим діалогу бота й обраний проєкт; ключ — id чату", "n8n", "n8n", "службові"),
    "evm_packages": ("гілка «EVM (класичний)»: базовий план пакетів", "міграції", "`evm_classic_*`", "фінансові"),
    "evm_package_done": ("гілка «EVM (класичний)»: факт виконання пакетів", "бот «Видано» (⬜)", "`evm_classic_*`", "фінансові"),
    "n8n_chat_histories": ("пам'ять LLM-агентів звіту, імпорту, зустрічі", "n8n (LangChain)", "n8n", "вільний текст, можливі ПІБ"),
    "archi_report_today": ("вʼю: колонка «Сьогодні» звіту (ETC, рентабельність, ймовірності)", "—", "Weekly Render, чат ПМа", "похідні"),
    "archi_snapshot_history": ("вʼю: історія знімків із сигналами (H-01, H-02, E-*)", "—", "Weekly Render", "похідні"),
    "archi_plan_execution": ("вʼю: виконання плану тижня (PX-01)", "—", "Weekly Render", "похідні"),
    "archi_weekly_progress": ("вʼю: приріст готовності проти витрат (P-10)", "—", "Owner View", "похідні, фінансові"),
    "evm_classic_today": ("вʼю: класичні показники на сьогодні", "—", "(екрана ще немає)", "похідні"),
    "project_metrics_live": ("застаріле вʼю: лінійна оцінка за годинами; **не використовувати**", "—", "ніхто", "похідні"),
    "rates_coverage_check": ("діагностика: пари проєкт–виконавець без ставки", "—", "ручна перевірка", "службові"),
}
GROUPS = [
    ("Клієнти, доступ, конфігурація", ["companies", "user_access", "company_thresholds", "archi_thresholds", "owner_prefs"]),
    ("Проєкти й тижневий ритм", ["project_metrics", "wr_weekly_snapshots", "wr_plan_items", "archi_wr_inbox"]),
    ("Факт: години, гроші, графік", ["time_log", "money_log", "payment_schedule", "rates"]),
    ("Журнали й стан бота", ["meeting_log", "kp_log", "archi_bot_mode_state", "n8n_chat_histories"]),
    ("EVM (класичний)", ["evm_packages", "evm_package_done"]),
    ("Вʼю", ["archi_report_today", "archi_snapshot_history", "archi_plan_execution", "archi_weekly_progress", "evm_classic_today", "project_metrics_live", "rates_coverage_check"]),
]


def esc(s):
    return str(s).replace("|", "\\|").replace("\n", " ")


def render():
    dumps = sorted(glob.glob(str(ROOT / "sql" / "schema" / "schema_dump_*.json")))
    if not dumps:
        raise SystemExit("немає sql/schema/schema_dump_*.json")
    src = Path(dumps[-1])
    d = json.loads(src.read_text(encoding="utf8"))
    cols = {}
    for c in d["columns"]:
        cols.setdefault(c["t"], []).append(c)
    cons, idx, trg = {}, {}, {}
    for c in d["constraints"]:
        cons.setdefault(c["t"], []).append(c)
    for i in d["indexes"]:
        idx.setdefault(i["t"], []).append(i)
    for t in d["triggers"]:
        trg.setdefault(t["t"], []).append(t)
    L = ["# ARCHI — схема бази даних (згенеровано)",
         "",
         "Згенеровано `scripts/gen_db_schema.py` зі знімка `%s` (живий Supabase `bxawceksdkqlbkdgjvyz`, схема `public`). **Не редагувати вручну:** змінюється знімок → перегенерувати → закомітити разом." % src.relative_to(ROOT),
         "Перевірка відповідності: `python3 scripts/gen_db_schema.py --check`. Оновлення знімка: `sql/schema/dump_query.sql`.",
         "Охоплено 19 таблиць і 7 вʼю ARCHI. Чужі таблиці в тій самій базі (`_bak_*`, `jarvis_*`, `shift_*`, `bot_*`, `archi_bot_semantic_memory`) не входять.",
         "",
         "## 1. Огляд",
         "",
         "| Об'єкт | Тип | Рядків | RLS | Політик | Призначення | Клас даних |",
         "|---|---|---|---|---|---|---|"]
    for g, names in GROUPS:
        for n in names:
            k = "вʼю" if d["kinds"][n] == "v" else "таблиця"
            r = d["rls"].get(n)
            L.append("| `%s` | %s | %s | %s | %s | %s | %s |" % (
                n, k, d["rows"].get(n, "—") if k == "таблиця" else "—",
                ("так" if r["rls"] else "ні") if r else "—", r["policies"] if r else "—", esc(META[n][0]), esc(META[n][3])))
    L += ["",
          "Рядків — оцінка `pg_stat_user_tables.n_live_tup` на дату знімка. Усі дані демо (`CLAUDE.md` п. 18).",
          "n8n підключається прямим з'єднанням Postgres і **обходить RLS**; ізоляцію клієнтів тримає фільтр `company_id` у запитах (`docs/W1_DESIGN.md` §4).",
          "",
          "## 2. Зв'язки (ER)",
          "",
          "Зовнішні ключі (FK) у базі є **лише** на `companies`. Між рештою таблиць зв'язок логічний через `(company_id, project_id)` без FK; це відомий борг (W1.1: «FK для логів не додані»).",
          "",
          "```mermaid",
          "erDiagram"]
    fks = [c for c in d["constraints"] if c["type"] == "f"]
    for c in fks:
        L.append("  %s }o--|| %s : \"%s\"" % (c["t"], c["def"].split("REFERENCES ")[1].split("(")[0], c["def"].split("(")[1].split(")")[0]))
    L += ["  companies ||--o{ project_metrics : \"company_id (логічно)\"",
          "  project_metrics ||--o{ wr_weekly_snapshots : \"(company_id, project_id)\"",
          "  project_metrics ||--o{ wr_plan_items : \"(company_id, project_id)\"",
          "  project_metrics ||--o{ time_log : \"(company_id, project_id)\"",
          "  project_metrics ||--o{ money_log : \"(company_id, project_id)\"",
          "  project_metrics ||--o{ payment_schedule : \"(company_id, project_id)\"",
          "  project_metrics ||--o{ meeting_log : \"(company_id, project_id)\"",
          "  project_metrics ||--o{ evm_packages : \"(company_id, project_id)\"",
          "  evm_packages ||--o{ evm_package_done : \"(company_id, project_id, package)\"",
          "```",
          ""]
    L += ["Позначка «логічно» — зв'язок без FK у БД. Кожна FK: " + (", ".join("`%s` → `%s`" % (c["t"], c["def"].split("REFERENCES ")[1]) for c in fks) or "немає") + ".", ""]
    n = 2
    for g, names in GROUPS:
        n += 1
        L += ["## %d. %s" % (n, g), ""]
        for name in names:
            m = META[name]
            L += ["### `%s`" % name, "",
                  "- Призначення: %s." % m[0],
                  "- Хто пише: %s." % m[1],
                  "- Хто читає: %s." % m[2],
                  "- Клас даних: %s." % m[3], ""]
            L += ["| № | Колонка | Тип | NULL | За замовчуванням |", "|---|---|---|---|---|"]
            for c in cols[name]:
                ty = c["ty"] if c["ty"] != "USER-DEFINED" else c["udt"]
                if c["ty"] == "ARRAY":
                    ty = c["udt"].lstrip("_") + "[]"
                if c["len"]:
                    ty += "(%s)" % c["len"]
                L.append("| %s | `%s` | %s | %s | %s |" % (c["n"], c["c"], ty, "так" if c["null"] == "YES" else "**ні**", ("`%s`" % esc(c["def"])) if c["def"] else ""))
            cs = cons.get(name, [])
            if cs:
                L += ["", "Обмеження:"]
                names_c = {"p": "PRIMARY KEY", "u": "UNIQUE", "f": "FOREIGN KEY", "c": "CHECK", "x": "EXCLUDE"}
                for c in sorted(cs, key=lambda x: (x["type"], x["name"])):
                    L.append("- %s `%s`: `%s`" % (names_c.get(c["type"], c["type"]), c["name"], esc(c["def"])))
            ix = idx.get(name, [])
            if ix:
                L += ["", "Індекси:"]
                for i in sorted(ix, key=lambda x: x["name"]):
                    L.append("- `%s`: `%s`" % (i["name"], esc(i["def"])))
            tg = trg.get(name, [])
            if tg:
                L += ["", "Тригери: " + ", ".join(sorted({"`%s` (%s %s)" % (t["name"], t["timing"], t["ev"]) for t in tg})) + "."]
            L.append("")
    n += 1
    L += ["## %d. Функції SQL (`archi_*`, `evm_*`)" % n, "", "| Функція | Аргументи | Повертає | SECURITY DEFINER |", "|---|---|---|---|"]
    for f in sorted(d["functions"], key=lambda x: (x["name"], x["args"])):
        L.append("| `%s` | `%s` | `%s` | %s |" % (f["name"], esc(f["args"]) or "—", esc(f["ret"]), "так" if f["sec"] else "ні"))
    L += ["", "Формули й пороги, які реалізують функції, — `docs/FORMULAS.md`. Перевантаження `p_company` читають пороги по компанії (W1.5).", ""]
    n += 1
    L += ["## %d. Політики зберігання й дані особисті" % n, "",
          "- Політики зберігання й видалення **не визначені** (OD-20, W10.8, W11.5). Нічого не архівується й не видаляється автоматично.",
          "- Дані з потенційно особистим змістом: `user_access` (Telegram id), `owner_prefs`, `time_log` (ПІБ або посада виконавця), `wr_*`, `meeting_log`, `archi_wr_inbox`, `n8n_chat_histories` (вільний текст).",
          "- Юридична перевірка — до першого клієнта (OD-20); юридичних висновків цей документ не дає.",
          "",
          "## %d. Відомі відхилення схеми від бажаного" % (n + 1), "",
          "| № | Факт зі знімка | Наслідок | Вузол карти |",
          "|---|---|---|---|"]
    nn = [c["t"] for c in d["columns"] if c["c"] == "company_id" and c["null"] == "YES" and d["kinds"][c["t"]] == "r"]
    L += ["| 1 | FK є лише на `companies` | немає цілісності між `project_metrics` і логами | W1.1 |",
          "| 2 | `company_id` допускає NULL: %s | `user_access`: так задумано (оператор); `archi_bot_mode_state`: колізія станів бота для оператора з кількома клієнтами | W1.6 |" % (", ".join("`%s`" % x for x in sorted(set(nn))) or "немає"),
          "| 3 | таблиці без `company_id`: %s | немає прив'язки до клієнта: `archi_thresholds` — значення за замовчуванням (перевизначення в `company_thresholds`); `n8n_chat_histories` — пам'ять LLM, ізоляція лише через `session_id` | W1.6, W3.6, DR-13 |" % (", ".join("`%s`" % t for t in sorted(t for t, k in d["kinds"].items() if k == "r" and t not in {c["t"] for c in d["columns"] if c["c"] == "company_id"})) or "немає"),
          "| 4 | RLS увімкнено, але політик немає на частині таблиць | публічний ключ нічого не читає, n8n (роль postgres) читає все | OD-4 |",
          "| 5 | `wr_plan_items_legacy` відсутня | дизайн D2 не виконано (245 рядків зі старими ID) | W1.1 |",
          "| 6 | Застарілі об'єкти: `project_metrics_live`, колонки `final_message`, `efficiency_contract`, `earned_value`, `paid_volume`, `comparison` | плутанина; видалення — рішення власника | T-12 |",
          ""]
    return "\n".join(L) + "\n"


if __name__ == "__main__":
    text = render()
    if "--check" in sys.argv:
        cur = OUT.read_text(encoding="utf8") if OUT.exists() else ""
        if cur != text:
            print("10_DATABASE_SCHEMA.md не збігається зі знімком: запустіть scripts/gen_db_schema.py")
            sys.exit(1)
        print("10_DATABASE_SCHEMA.md збігається зі знімком")
    else:
        OUT.write_text(text, encoding="utf8")
        print("записано %s (%d КБ)" % (OUT.relative_to(ROOT), len(text) // 1024))
