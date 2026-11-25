# ARCHI — репозиторій продукту

**Доповнення 25.11.2026 (`RELEASE_PLAN` §221):** Supabase — проєкти 22-24, 24-11, 24-37, 24-52 перенесено в компанію `ARCHIVE` (п. 49); відкат `sql/2026-11-25_archive_4_projects_p49_rollback.sql`. n8n без змін.

**Доповнення 25.11.2026 (`RELEASE_PLAN` §222):** core `e1176fb0-c3f8-499d-82bd-fac02c2a8c98` (199 вузлів; вкладка «Кошторис» в Owner View; відкат `8f4a823f-3fd5-491b-a60c-50116b40cfbf`); Supabase — функція `koshtorys_tab_data`.

**Доповнення 25.11.2026 (`RELEASE_PLAN` §218):** Supabase — `archi_morning_brief`: незданий звіт за минулий тиждень, усі прострочені акти (за `money_log`), «не потрібно» не є ескалацією; відкат `sql/2026-11-24_archi_morning_brief_n2n3n5_rollback.sql`. n8n без змін.

**Доповнення 11.11.2026 (§190): core `4a5df71b` (197 вузлів; збій LLM → повідомлення ПМу, повтор, temperature 0.2), Morning Brief `911fa93b` (позначка «тексти за шаблонами»), новий workflow LLM Health Check `Sna7JWxq3BpRDJIs` (щодня 07:30). Рахунок Anthropic вичерпано до поповнення власником.
**Доповнення 4 20.11.2026 (`RELEASE_PLAN` §204, додаток 3):** core `8f4a823f-3fd5-491b-a60c-50116b40cfbf` (П2h; відкат `77dd745b-3589-4ac8-a207-3726ce25a98a`).

**Доповнення 3 20.11.2026 (`RELEASE_PLAN` §204):** core `77dd745b-3589-4ac8-a207-3726ce25a98a` (П2g: верстка чат-картки кодом, п. 4; відкат `17c47202-2baf-457e-a201-20b4e7236667`).

**Доповнення 2 19.11.2026 (`RELEASE_PLAN` §203):** core `17c47202-2baf-457e-a201-20b4e7236667` (W1.8 крок 3: кольори й сигнали Owner View з SQL; відкат `730b080f-3a60-4703-adbc-e5f3b613a79c`).

**Доповнення 19.11.2026 (`RELEASE_PLAN` §202):** core `730b080f-3a60-4703-adbc-e5f3b613a79c` (П2f.2: діагностика блоку «Висновок»; попередня `3cd872a8-49a4-4a34-be8a-18509fb77e74` (П2f.1: Sanitize без відкидання блоку; попередня `db831301-d3fd-40c2-b49f-035a12c7845c` (197 вузлів; П2f: B-28, кілька дій по маршрутах, розбиття повідомлень; відкат `a42e90b8-3c61-4613-8174-0d77ee720ccd`). Supabase: `archi_morning_brief` з `advices`/`events`. Eval-стенд `scripts/eval/` (W15.1).
**Доповнення 17.11.2026 (`RELEASE_PLAN` §200):** core `a42e90b8-3c61-4613-8174-0d77ee720ccd` (197 вузлів; П2e; спроба fix «Б» з моделлю haiku-5-5 (`918ee03b-2f3c-4330-af0e-6938074f1eeb`) відкочена: API 400 «temperature is deprecated for this model»); таблиця адресатів порад — `docs/BRIEF_ADDRESSEE_RULES.md`; Telegram-перевірка власника відкрита.

**Доповнення 15.11.2026 (`RELEASE_PLAN` §198):** core `34f82ff5-89dd-4c6f-bd8e-8de89a229cba` (197 вузлів; П2d: потреба блокера і Impact без прогнозів; відкат `d04ef8a0-edf0-4fc7-af08-2471d859a310`);
**Доповнення 15.11.2026 (`RELEASE_PLAN` §197):** core `d04ef8a0-edf0-4fc7-af08-2471d859a310` (197 вузлів; П2c: короткий JSON-промпт картки чату; відкат `5b0dd3e2-3afe-47f0-adee-05299acc3da1`);
**Доповнення 15.11.2026 (`RELEASE_PLAN` §196):** core `5b0dd3e2-3afe-47f0-adee-05299acc3da1` (197 вузлів; П2b: картка чату від коду, JSON від LLM; відкат `c9a11286-ba6d-4406-a832-61917a7de21b`); Telegram-перевірка — власник.
**Доповнення 13.11.2026 (`RELEASE_PLAN` §195):** core `c9a11286-ba6d-4406-a832-61917a7de21b` (197 вузлів; B-20 Щотижневий рендер — одноразове обчислення вʼю, було 166 с у вузлі, `d97dbabe`; B-17 валідатор відповіді чату); відкат `d97dbabe`, далі `4a5df71b`; відкат даних DEMO-01; беклог і план правок за тестами Telegram — `docs/DEMO_BACKLOG_2026-11-13.md`, `docs/DEMO_FIX_PLAN_2026-11-13.md`.

**Доповнення 11.11.2026 (V5, V9, W12; `RELEASE_PLAN` §191–§193):** формат чисел Weekly Render і Owner View, рішення V9 (1А 2А 3Б 4Б), перевизначення плану `company_thresholds` для DEMO; карта доповнена потоком W12 «Фінансова ліквідність власника» (лише зафіксовано, не реалізовано; `CLAUDE.md` п. 36). Ці зміни входять у core `4a5df71b`.

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
                                        activeVersionId eb57069b-a23e-4879-959f-9c0516c178d9,
                                        193 вузли (експорт 07.11.2026). Токен бота замінено
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
