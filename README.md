# ARCHI — репозиторій продукту

**Стан на 29.10.2026:** n8n `CKwCsGIwyw9feCY5` `2f74af2a`, 179 вузлів (§139: колір ⛔/Q8 з коду, K6sm `cf904641`); аудит документації — `docs/DOC_AUDIT_29.10.2026.md`.

Оркестраційний шар над проектними даними архітектурно-будівельної компанії
(Telegram Chat-агент + Owner View Mini App + Щотижневий WR-цикл).

⚠️ **Цей репозиторій — публічний.** До 13.09.2026 продукт розроблявся напряму
в n8n і в чат-сесіях, без git. Це перше перенесення коду під версійний
контроль — репозиторій свідомо repurposed з порожнього `fdo-perfect`
(історичний сміттєвий репо), бо GitHub-інтеграція цієї сесії не мала права
створити новий репозиторій, а всі вільні репозиторії акаунту публічні.
Власник (Андрій Матвєєв) підтвердив push "як є" з прийняттям ризику —
див. `SECURITY.md`.

## Структура

```
workflows/
  DEMO_Archi_Agent_Core.json         — головний n8n workflow (id CKwCsGIwyw9feCY5,
                                        n8n instance osbbcopilot.app.n8n.cloud).
                                        Переекспортовано 29.10.2026,
                                        activeVersionId 2f74af2a-421c-4846-a42f-492f2f8e8757,
                                        179 вузлів (29.10.2026: колір заголовків карток і лічильник Q8 з коду, §139; P-09 на канон стадій, §136; назви Archi без «CPI»/«EVM», §135; P-10 «за чиї гроші», §131; 27–28.10.2026: параметризований SQL у 6 вузлах, RELEASE_PLAN §116 і §118; раніше дата за
                                        Києвом, §114, блокер і його тип лише зі слів ПМа, §111). Історія версій — у
                                        `docs/RELEASE_PLAN.md` (§48–§136) і в git.
                                        Токен бота в експорті замінено на `<TELEGRAM_BOT_TOKEN>` (SECURITY.md п. 1).
                                        ⚠️ Як завжди: цей файл застаріє одразу після
                                        наступної сесії редагування в n8n, якщо його
                                        не переекспортувати — перевіряти дату/versionId
                                        тут проти живого workflow, не довіряти мовчки.
  Archi_Protocol_Format_Helper.json  — діагностичний/scratch workflow
                                        (id LK4tBGMPiwIgpoki), read-only helper,
                                        не production-критичний

docs/  (порядок читання — `CLAUDE.md` «Порядок читання»; аудит документації — DOC_AUDIT_29.10.2026.md)
  Еталони (чинні):
  TRANSITION_PROMPT_2026-10-29.md    — ЧИННИЙ перехідний промпт v4 (читати першим після CLAUDE.md)
  ARCHI_TECH_SPEC_v3_0.md            — ЧИННА технічна специфікація (15.10.2026, звірено 29.10.2026)
  FORMULAS.md                        — довідник усіх формул (ID D/E/F/S/P/V/R/H/PX), єдине
                                        джерело визначень показників (v1.7)
  WEEKLY_REPORT_FORM.md              — форма звіту ПМа і специфікація Weekly Render (§2)
  LAYOUT_STANDARD.md                 — стандарт верстки «стовпчиком» і словник емодзі
  RELEASE_PLAN.md                    — журнал робіт §0–§139 (читати з кінця)
  CTO_CHECKPOINT_PROMPT.md           — промпт аудиту коду проти документації
  NODE_MAP.md                        — карта всіх 179 вузлів (генерує scripts/gen_node_map.py; руками не правити)
  ARCHI_Obraz_Idealnoho_Rezultatu.md — методологія «навіщо» (05.09.2026, доповнено 26.09.2026)
  Плани й промпти:
  EVM_CLASSIC_PLAN.md                — план вкладки EVM (⚠️ не відповідає CLAUDE.md п. 13 — переглянути)
  DEMO_PLAN_2026-10-28.md            — план демо Ф1 (03.11.2026)
  DEMO_REPORT_TEXTS_2026-10-30.md    — сценарні тексти звітів ПМа для живого циклу 30.10
  OWNER_MORNING_TEST.md              — текст тесту для власника
  START_PROMPT_DOC_AUDIT.md          — стартовий промпт аудиту документації (виконано 29.10.2026)
  START_PROMPT_POST_AUDIT.md         — стартовий промпт наступної сесії: рішення за аудитом → місія EVM
  FEATURE_IDEAS.md                   — реєстр ідей власника (не в розробці)
  Аудити: CTO_CHECKPOINT_16/18/22/25/29.10.2026.md (датовані звіти), DOC_AUDIT_29.10.2026.md
  Історія — docs/archive/ (перелік і чим замінено — docs/archive/README.md);
    TRANSITION_PROMPT_2026-10-25.md (v3) лишився в docs/: розділи 2–8, 10–15 ще чинні

sql/                                 — SQL-зміни Supabase по датах (2026-10-17…2026-10-29),
                                        demo_seed_2026-10-17/ (генератор і скрипти демо-даних),
                                        demo_seed_2026-10-29/ (демо-години + rollback.sql)
scripts/                             — check_report_form.py; gen_node_map.py (→ docs/NODE_MAP.md); replay/ (код вузлів на живих даних)
tests/                               — тести `WR: Parse Agent Output` (tests/README.md)
CLAUDE.md                            — закриті рішення власника п. 1–14, ритуал старту

SECURITY.md                          — відомі проблеми безпеки, прийняті ризики;
                                        п.5 (26.09.2026) — Supabase RLS вимкнений
                                        на ключових таблицях; п.6 (04.10.2026) —
                                        нова таблиця kp_log теж без RLS, той самий
                                        клас проблеми; обидва НЕ виправлені, чекають
                                        рішення власника
```

## Що НЕ в цьому репозиторії (свідомо)

- `Archi Representative Telegram Bot` (n8n id `I3K5tBj0FWF1dbWb`) — окремий
  проєкт (представник замовника + Dispatcher), не частина ARCHI Owner
  View/WR-agent продукту. За рішенням власника — не чіпати, не включати сюди.
- Одноразові setup-workflow (`Archi Flat - Gate Setup M0.1`,
  `Archi Flat Link Test 01`, `Archi Flat - Fix Percent Format`,
  `DEMO Archi — Check Contract+Graphik`) — неактивні, історичні, не код
  продукту.
- Google Sheets документи (Кошторис, Protocol) — це зовнішні дані/адаптери,
  не код. ID перелічені в ТЗ, розділ "Environment Registry". **Flat і Weekly
  Log — прибрані з продукційного контуру workflow 25.09.2026** (RELEASE_PLAN.md
  Розділ 8); Google Sheets документи як такі не видалені, просто бот їх
  більше не читає.
- Тимчасовий workflow `SPhB65LRmYi8ff3R` ("DEMO Flat -- Get Real Formulas
  (Temp)") — писав у Weekly Log, зайвий після його видалення, **заархівований
  26.09.2026**.

## Як синхронізувати далі

n8n Cloud (Starter/Pro) не має вбудованого git-sync. Дисципліна поки що
ручна: після кожної публікації в n8n — повний live JSON через MCP
`get_workflow_details` із заглушкою `<TELEGRAM_BOT_TOKEN>` і закомітити сюди
(правила — `CLAUDE.md` «Правила n8n через MCP»; раніше — `Download` у меню workflow). Це
тимчасовий процес до автоматизації (backlog-пункт, не в поточному
release-плані).
