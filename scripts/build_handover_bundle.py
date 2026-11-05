#!/usr/bin/env python3
"""ARCHI — збірка пакета передачі в один файл `docs/handover/ARCHI_FULL_PACKAGE.md` (stdlib).

Запуск з кореня репозиторію:  python3 scripts/build_handover_bundle.py
Кожне джерело вставляється ДОСЛІВНО; перед ним — рядок-маніфест з sha256 (перевіряє `check_handover.py`, A12).
`docs/RELEASE_PLAN.md` (журнал, ~540 КБ) і `docs/archive/` не входять: це історія, а не специфікація.
"""
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "handover" / "ARCHI_FULL_PACKAGE.md"

PARTS = [
    ("ЧАСТИНА I — Пакет передачі: що це, для кого, як читати", [
        ("docs/handover/00_START_HERE.md", "Навігація, стан, чек-лист передачі"),
        ("docs/handover/01_PRODUCT_BRIEF.md", "Продуктовий бриф для Product Manager"),
        ("docs/handover/02_BUSINESS_REQUIREMENTS.md", "Бізнес-вимоги"),
        ("docs/handover/03_TECHNICAL_CTO.md", "Технічний документ для CTO"),
        ("docs/handover/04_METHODOLOGY_FOR_DEVELOPERS.md", "Методологія для розробників"),
        ("docs/handover/10_DATABASE_SCHEMA.md", "Схема БД (згенеровано зі знімка)"),
        ("docs/handover/11_API_CONTRACT.md", "API-контракт"),
        ("docs/handover/openapi.yaml", "OpenAPI 3.0"),
        ("docs/handover/12_ERROR_AND_EDGE_CASES.md", "Помилки, порожні стани, крайні випадки"),
        ("docs/handover/13_USER_FLOWS.md", "Потоки користувача (Mermaid)"),
        ("docs/handover/14_THREAT_MODEL.md", "Модель загроз (STRIDE)"),
        ("docs/handover/15_USER_STORIES.md", "User Stories з Acceptance Criteria"),
        ("docs/handover/16_NFR.md", "Нефункціональні вимоги: цілі власника й стан"),
    ]),
    ("ЧАСТИНА II — Перевірка пакета", [
        ("docs/handover/05_CTO_REVIEW_PLAN.md", "План перевірки пакета CTO"),
        ("docs/handover/06_REVIEW_VALIDATION_PLAN.md", "План валідації результатів перевірки"),
        ("docs/handover/07_REVIEW_REPORT.md", "Звіт про перевірку за планом"),
        ("docs/handover/08_CODE_VS_DOCS_AUDIT_PROMPT.md", "Промпт: перевірка існуючого коду проти документації"),
    ]),
    ("ЧАСТИНА III — Канон: рішення, карта, специфікації", [
        ("CLAUDE.md", "Закриті рішення власника п. 1–33, ритуал і правила сесії"),
        ("docs/DECISIONS_REGISTER.md", "Реєстр закритих рішень і суперечностей"),
        ("docs/ROADMAP_TO_RELEASE.md", "Єдина карта розробки до релізу"),
        ("docs/ARCHI_TECH_SPEC_v3_1.md", "Технічна специфікація v3.1"),
        ("docs/FORMULAS.md", "Довідник формул і порогів"),
        ("SECURITY.md", "Відомі ризики безпеки"),
    ]),
    ("ЧАСТИНА IV — Додаткові специфікації й методологія", [
        ("docs/ARCHI_Obraz_Idealnoho_Rezultatu.md", "Методологія й концепція"),
        ("docs/W1_DESIGN.md", "Дизайн багатоклієнтності"),
        ("docs/WEEKLY_REPORT_FORM.md", "Форма звіту ПМа і Weekly Render"),
        ("docs/LAYOUT_STANDARD.md", "Стандарт верстки текстів"),
        ("docs/EVM_CLASSIC_PLAN.md", "План гілки «EVM (класичний)»"),
        ("docs/EVM_CLASSIC_DESIGN.md", "Дизайн гілки «EVM (класичний)»"),
        ("docs/OWNER_MORNING_TEST.md", "Тест для власника"),
        ("docs/FEATURE_IDEAS.md", "Ідеї власника: чат проєкту, виконавці"),
        ("docs/HANDOVER_CTO.md", "Пакет передачі CTO Senior (v1, 02.11.2026)"),
        ("docs/CTO_CHECKPOINT_03.11.2026.md", "Останній аудит коду проти документації"),
        ("docs/NODE_MAP.md", "Карта вузлів core workflow (генерується)"),
        ("docs/MORNING_BRIEF_PROMPT.txt", "Системний промпт ранкового брифінгу"),
    ]),
]


def main():
    out = ["# ARCHI — повний пакет документації для передачі розробки",
           "",
           "Зібрано автоматично `scripts/build_handover_bundle.py`. Кожен документ вставлено дослівно; `<!-- SOURCE … -->` містить sha256 джерела.",
           "Не входять: `docs/RELEASE_PLAN.md` (журнал робіт, ~540 КБ, читати з кінця в репозиторії), `docs/archive/`, `sql/`, `workflows/` (код і експорти лише в репозиторії).",
           "Номери «п. N» означають пункти закритих рішень у `CLAUDE.md`. Починати з Частини I, документ 00.",
           "",
           "## Зміст", ""]
    n = 0
    for title, items in PARTS:
        out.append("**%s**" % title)
        for path, desc in items:
            n += 1
            out.append("%d. `%s` — %s" % (n, path, desc))
        out.append("")
    out.append("---")
    for title, items in PARTS:
        out += ["", "# " + title, ""]
        for path, desc in items:
            data = (ROOT / path).read_bytes()
            txt = data.decode("utf8")
            sha = hashlib.sha256(data).hexdigest()
            out += ["", "---", "",
                    "<!-- SOURCE %s sha256=%s bytes=%d -->" % (path, sha, len(data)),
                    "**Джерело: `%s` — %s**" % (path, desc), "",
                    txt.rstrip("\n"), ""]
    OUT.write_text("\n".join(out) + "\n", encoding="utf8")
    print("збірка: %s, джерел %d, %d КБ" % (OUT.relative_to(ROOT), n, OUT.stat().st_size // 1024))


if __name__ == "__main__":
    main()
