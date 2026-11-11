# ARCHI — репозиторій продукту

**Доповнення 11.11.2026 (§190): core `4a5df71b` (197 вузлів; збій LLM → повідомлення ПМу, повтор, temperature 0.2), Morning Brief `911fa93b` (позначка «тексти за шаблонами»), новий workflow LLM Health Check `Sna7JWxq3BpRDJIs` (щодня 07:30). Рахунок Anthropic вичерпано до поповнення власником.

**Стан на 05.11.2026 (DR-14, §180): core `CKwCsGIwyw9feCY5` `978db8b8` (193 вузли; ack «⏳ Готую відповідь», fallback чату, повтор і таймаут `Call Anthropic`, Error Workflow `JZ5htUtbMaWTagoC`); відкат `a4c89c3c`. Раніше (W5.7, §174): додано workflow «ARCHI: Morning Brief» `J3Oqcaa2YBEsVSng` (11 вузлів, опублікований, розсилка 08:30 пн–пт ввімкнена (§175); експорт — `workflows/Archi_Morning_Brief.sdk.ts`); core без змін. Попередньо — **Стан на 03.11.2026 (W1, §165): core `a4c89c3c-3892-40d0-91e6-7e9ba5eb49d9` (191 вузлів, пороги по компанії §171, колір hero-карток §166, колір таблиць §167, `company_id` у всіх запитах, резолвер компанії), K6sm `23c5765e`, RC7H `6a8d9dbe`; Supabase M0–M6 застосовано. Попередньо: core `40abff53` (179 вузлів; виправлено `WR: Detect Doc Type`, `RELEASE_PLAN` §160; відкат `bc449cbd`); `CLAUDE.md` п. 26 (дати релізів скасовано; свіжість = дата оновлення). K6sm і RC7H експортовано в `workflows/` (§158); CTO Checkpoint 02.11 (§159). Попередньо — стан на 02.11.2026: створено єдину карту `docs/ROADMAP_TO_RELEASE.md` і стартовий промпт сесії-штабу `docs/START_PROMPT_HQ.md` (RELEASE_PLAN §149; `CLAUDE.md` п. 19–20). Попередньо — стан на 01.11.2026 (місія EVM, сесія EVM-2: Supabase — джерело плану, `CLAUDE.md` п. 17; `evm_packages`, `evm_package_done` з 100 демо-пакетами (§143), функції й в'ю `evm_classic_*` (§144); n8n не змінювався). Попередньо — стан на 31.10.2026 (сесія EVM-1, §142) і 30.10.2026:** n8n `CKwCsGIwyw9feCY5` `bc449cbd`, 179 вузлів (§141: п. 15 на індекси, план тижня й узгодженість, колонка «Різниця»; §140: п. 15 — від'ємна розбіжність 🔴, план зелений; §139: колір ⛔/Q8 з коду, K6sm `cf904641`); аудит документації — `docs/DOC_AUDIT_29.10.2026.md`.

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
CLAUDE.md                            — закриті рішення власника (п. 1–23), ритуал старту, правила сесії
SECURITY.md                          — відомі ризики безпеки і прийняті рішення (RLS, токен, доступ)

workflows/
  DEMO_Archi_Agent_Core.json         — головний n8n workflow (id CKwCsGIwyw9feCY5,
                                        n8n instance osbbcopilot.app.n8n.cloud),
                                        activeVersionId 978db8b8-1193-4db9-acb7-84cd21d61214,
                                        193 вузли (експорт 05.11.2026). Токен бота замінено
                                        на `<TELEGRAM_BOT_TOKEN>`. Файл застаріє після
                                        наступної публікації в n8n: звіряти versionId з живим.
  Archi_Protocol_Format_Helper.json  — діагностичний workflow (id LK4tBGMPiwIgpoki), не production-критичний

docs/                                — документи; індекс, рівні й правила оновлення — docs/README.md
  Читати: CLAUDE.md → docs/DECISIONS_REGISTER.md → docs/ROADMAP_TO_RELEASE.md →
          docs/TRANSITION_PROMPT_2026-11-02.md → docs/RELEASE_PLAN.md (з кінця)
  docs/archive/                      — історія (перелік — docs/archive/README.md)

sql/                                 — SQL-зміни Supabase по датах (файл + відкат тим самим комітом);
                                        demo_seed_*/ (демо-дані), seed/ (знімки для імпорту)
scripts/                             — check_docs.py (узгодженість документації),
                                        check_report_form.py, gen_node_map.py (→ docs/NODE_MAP.md), replay/
tests/                               — тести `WR: Parse Agent Output` (tests/README.md)
```

**Перевірка перед комітом документації:** `python3 scripts/check_docs.py` (0 помилок).

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
