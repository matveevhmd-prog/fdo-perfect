# CTO Checkpoint — 30.10.2026

Живий `activeVersionId`: `bc449cbd-e249-4972-a5d5-e9cd507353b1` (`get_workflow_history`, n8n `CKwCsGIwyw9feCY5`, опубліковано 30.10.2026 05:57 UTC, §141) | Репо (`main` після PR #103): `bc449cbd-…`, 179 вузлів | **Збіг версії: так.** Перша частина checkpoint (ранок 30.10) писалась на застарілому `main` (`9581c7e3`): паралельна сесія за час моєї роботи опублікувала 4 версії (п. 15 на індекси, §141) і міграцію `p15_indices_red_20261030`; частину 1 перевірено вдруге після оновлення. Побайтна звірка `parameters` усіх вузлів з live **не виконувалась** (див. «Не перевірено»).
Підсумок: **P0 0 · P1 3 · P2 5**
Режим: лише читання (n8n `get_workflow_history`; Supabase `SELECT`; аналіз файлу репо). Код і дані не змінювались.
Попередній checkpoint: `CTO_CHECKPOINT_29.10.2026.md` (`b100e952`). Після нього — 4 публікації n8n (§135–§140).

**Обсяг (чесно): вибірковий, не повний.** Виконано: крок 0 (збіг версії), A-1, A-3, A-4 (за файлом), C-3 (усі 18 рядків `project_metrics`), C-4, R-form, тести, grep «залишок», токен у вузлах і репо, кількість вузлів. Не виконано: S-check, P-check, F-check (`pg_get_functiondef`), R-check, крок 3 (таблиця «показник × контур»), крок 5 (маршрутизація), RLS, A-5, побайтна звірка з live. Для демо-кадру це означає: **числа в базі перевірені, а показ цих чисел на екранах — ні.**

## Знахідки

| # | Пріор. | Тип | Де | Еталон | Факт (доказ) | Рекомендація | Рішення від |
|---|---|---|---|---|---|---|---|
| 1 | P1 | DATA | `project_metrics.data_updated_at`, `wr_weekly_snapshots` | `DEMO_PLAN` §5 D0 (≤ 7 днів, `max(week_start)` = поточний понеділок) | **Live SQL 30.10:** жоден проєкт не має знімка 26.10, окрім тестового DEMO-03. Останній звіт 12.10 — 11 проєктів (18 днів), DEMO-08 — 21.09 (39 днів). `data_updated_at` старший за 7 днів (13 днів, 17.10): 24-11, 24-37, DEMO-04-АН, DEMO-05, DEMO-05-АН, DEMO-08, DEMO-08-АН; DEMO-01-АН — `NULL` | Живий цикл (С1); до його завершення D0 не пройдено | власник проходить звіти |
| 2 | P1 | DATA | склад циклу (14 проєктів у `project_metrics` без АН) | `DEMO_REPORT_TEXTS` | Тексти звітів є для 12 проєктів; **немає** для DEMO-03 (є знімок 12.10 `id` 59 і тестові `id` 217, 222) і 24-37 (знімків немає взагалі; `project_metrics`: план годин МБР 2266,08 / П 2280 / Р 2360, факт МБР 56,5). Для DEMO-08 знімка 12.10 немає — база тексту (стадії 100%) не підтверджена базою | Рішення власника про склад циклу (Q1 у `DEMO_PLAN` §8); числа 24-37 — лише від власника (п. 9) | власник |
| 3 | P1 | DATA | `time_log` (`source='demo_2910'`, 80 рядків) | `CLAUDE.md` «Перевірка цифр» | **Не перевірено 30.10**, знахідка успадкована з checkpoint 29.10 #3: вигадані демо-години в живій таблиці; відкат — до Ф3 (рішення власника) | Не показувати як «реальні» числа без позначки; відкат після показу | власник |
| 4 | P2 | ARCH | `Build MiniApp Data`, `AN: Attach Block` (grep порогів `0.85/0.95/rent_drop/etc_red/unpaid_/cpi_red/RULES/rule(`: рівно ці 2 вузли) | `TECH_SPEC` §2.1 (A-1) | Не змінилось з 29.10 #1: блок АН дублює пороги | Окрема ітерація | власник |
| 5 | P2 | ARCH | вузли без `main`-зв'язків: `WR: Schedule Reminder (Fri 10:00)` (відомий D1); `WR: OpenAI Chat Model`, `WR: Postgres Chat Memory`, `Import: Postgres Chat Memory`, `Meeting: Postgres Chat Memory` | `TECH_SPEC` (A-4) | Три підвузли LangChain, імовірно, підключені через `ai_*` (мій скрипт їх не враховує) — **[Припущення]**, не підтверджено | Перевірити `ai_*` у наступному checkpoint | — |
| 6 | P2 | DOC | allowlist `304884647` | `START_PROMPT_DEMO_AND_CLOSE` G1 («`ALLOWED` — 5 вузлів») | У файлі репо `304884647` у **4** вузлах. Розбіжність 4 vs 5 не з'ясована (інше визначення «ALLOWED» або застарілий лічильник) — **Потребує перевірки** | Звірити з live | — |
| 7 | P2 | TXT | 8 вузлів, у яких є слово «залишок»: `Build Request Body`, `Fetch All Weekly Snapshots`, `Fetch Project Metrics (Chat)`, `Fetch Project Metrics (MiniApp)`, `Fetch Weekly Snapshots For Grid`, `WR: Build WR Prompt`, `WR: Save Weekly Snapshot`, `Xlsx: Build Rows` | `CLAUDE.md` п. 1; `CTO_CHECKPOINT_PROMPT` крок 4 | Допустимо лише в назвах колонок БД (`залишок_прогноз_год` тощо) і в забороняючих інструкціях. **Вміст не розібрано** — чи є текст для людини, невідомо | Розібрати перед записом (D4) | — |

## Перевірено й відповідає (з доказом)

- **Збіг версії.** `get_workflow_history`: верхня версія `9581c7e3-54a4-4ed9-ab86-7c79c95337da` «п.15 кольори: чат — нормативи під нові пороги…» (live n8n); у файлі репо `versionId` той самий; 179 вузлів, `executionOrder v1`.
- **C-3 (live SQL, усі 18 рядків `project_metrics`).** `ac_indep = ac_db` і `cf_indep = cf_db` у кожному рядку; де `cf` порожній (24-37, DEMO-02) — порожній в обох.
- **A-3.** 5 тригерів `archi_recalc_money`, `_plan`, `_schedule`, `_time`, `_wr` (`information_schema.triggers`; рядків більше 5, бо тригер повторюється по подіях).
- **Токен.** У вузлах файлу репо реального токена 0; заглушка `<TELEGRAM_BOT_TOKEN>` у 1 вузлі; `grep -rE '[0-9]{8,}:AA[A-Za-z0-9_-]{30,}'` по репо поза `.git/` — 0 файлів (повторна перевірка живого n8n не виконувалась).
- **R-form.** `python3 scripts/check_report_form.py` → «Розбіжностей: 0».
- **Тести.** `node tests/wr_parse_agent_output/run.js` → пройдено 29, провалено 0.
- **Перенос плану на 26.10.** 27 рядків `wr_plan_items` з `week_start = 2026-10-26`, `origin_week = 2026-10-19`, `pending` (live SQL, по 11 проєктах).

## Не вдалося / не виконано (чому)

- Побайтна звірка `parameters` усіх вузлів з live — потребує `get_workflow_details` на 179 вузлів; на цьому кроці інструмент був доступний, але звірку не запускав (обсяг). Збіг підтверджено лише за `versionId`.
- S-check, P-check, F-check, R-check, «показник × контур», A-5, маршрутизація, RLS — не виконувались; **числа на екранах Owner View / Weekly Render цим checkpoint не підтверджені.**
- Вигляд Mini App і Telegram — Claude не відкриває; оцінює власник за скрінами.

## Зміни відносно попереднього checkpoint (29.10)

- Нова версія n8n `9581c7e3` (було `b100e952` на момент checkpoint): правило кольору п. 15, §140.
- Знахідка 29.10 #2 (токен у git-історії) і #6–#7 (P-10) цим checkpoint не перевірялись — залишаються як у 29.10.
- Нова знахідка #2: склад циклу не збігається з кількістю проєктів у базі; DEMO-08 без знімка 12.10.

## Частина 2: код проти специфікації після оновлення `main` (30.10.2026, `bc449cbd`)

Режим: лише читання (Supabase `SELECT`, файл репо). Виконано: пороги БД проти `FORMULAS` §6; резервні значення `rule('key', default)` у вузлах проти БД (A-2); SQL-функції сигналів проти `FORMULAS`; перегенерація вузлів з файлу репо; тести.

### Перевірено й відповідає
- **Пороги БД ↔ `FORMULAS` §6 (live SQL, 31 ключ `archi_thresholds`, звірка вручну).** Збігаються всі: індекси і `cpi_*` = 1 / 1, `wr_ready_gap_pp` = 0, `plan_exec_*` = 100 / 100, `etc_*`, `rent_drop_pp*`, `profit_*_pct`, `slip_red_days` = 0, `unpaid_*` 0,10 / 0,25, `doc_prob_*` 6 / 3, `block_red_days` 14, `readiness_gap_pp` 20, `opt_*` 0,40 / 50, `plan_year_*`.
- **Міграція `p15_indices_red_20261030`.** Є в БД (`list_migrations`) і в репо (`sql/2026-10-30_p15_indices_red.sql` та відкат).
- **SQL-сигнали.** `archi_idx_signal`, `archi_flow_idx_signal`: `round(p,2) < idx_red` → red, інакше green (жовтого при `idx_yellow` = 1 немає). `archi_ready_gap_signal`: `round(p_pp,1) > wr_ready_gap_pp` → red. `archi_etc_gap_signal`, `archi_vac_signal`: перевитрата > 0 → red, `<= 0` → green. Усе відповідає `CLAUDE.md` п. 15.
- **Тести.** `check_report_form.py` — розбіжностей 0; `wr_parse_agent_output` — 29/0.
- **Ключі `wr_ready_gap_pp` і `plan_exec_*` не читаються вузлами n8n за `rule()`**: перший читає SQL-функція `archi_ready_gap_signal`, другі — в `Build MiniApp Data` і вʼю `archi_plan_execution`. Це не дефект, але `FORMULAS` має це вказувати (P2, нижче).

### Нові знахідки
| # | Пріор. | Тип | Де | Еталон | Факт | Рекомендація |
|---|---|---|---|---|---|---|
| 8 | P2 | ARCH | `Build MiniApp Data`, `AN: Attach Block`: резервні значення `rule('key', default)`; SQL `COALESCE` у `archi_etc_gap_signal`, `archi_vac_signal` | A-2: резервне значення в коді = значенню в БД | Код: `cpi_red` 0,85, `cpi_yellow` 0,95, `idx_red` 0,7, `idx_yellow` 0,9, `etc_red` 0,1, `etc_yellow` 0,05, `profit_red_pct` 10, `profit_yellow_pct` 5, `rent_drop_pp` 5, `rent_drop_pp_red` 10, `slip_red_days` 14. БД: 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0. SQL `COALESCE`: etc 0,10 / 0,05. Резервні значення спрацюють, лише якщо рядка порогу в `archi_thresholds` немає (не перевіряв, чи таке можливо); тоді екран покаже старі пороги | Привести резервні значення до БД окремою ітерацією; не до 03.11 (зміна n8n) |

### Не виконано (чесно)
- F-check: `pg_get_functiondef('archi_recalc')` по F-01…F-23 не звірявся.
- S-check і P-check по рядках `FORMULAS` §3–4 для `Build MiniApp Data` (45 КБ коду) — лише пороги й ключі, не кожна умова.
- R-check (`WR: Build WR Prompt`, `WR: Parse Agent Output`) — крім тестів 29/0.
- Крок 3 («показник × контур»), маршрутизація, RLS, A-5.
- Replay екранів (`scripts/replay/`) на live-даних — не запускався.
- Чи читає `demo_asof` SQL (функція/вʼю) — перевірив лише вузли n8n (не читають); БД не перевіряв.
- Повторна побайтна звірка вузлів з live — не виконувалась, збіг лише за `versionId`.
