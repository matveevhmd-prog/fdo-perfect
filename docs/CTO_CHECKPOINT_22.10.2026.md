# CTO Checkpoint — 22.10.2026

Живий `activeVersionId`: `868f0316-bb59-4958-9d73-2f457fa40459` (173 вузли, `updatedAt` 2026-10-22T06:49:20Z) | Репо: `versionId 868f0316…` (173) | **Збіг: так** (0 відмінностей у `parameters` 173 вузлів, `connections` ідентичні). Розбіжність знайдено лише в полі `activeVersionId` файлу репо (`89f82443` проти `868f0316`) — виправлено цим комітом (знахідка 10).
Підсумок: **P0 0 · P1 8 · P2 8** · Підтверджено інваріантів 2/5 (A-1 ✗, A-2 частково, A-3 ✓, A-4 ✓, A-5 не перевірявся).
Режим: лише читання (n8n `get_workflow_details`, `search_workflow_executions`; Supabase `SELECT`). Код і дані не змінювались; змінено лише документи (§ «Зміни в репозиторії»).
Попередній checkpoint: `CTO_CHECKPOINT_18.10.2026.md` (176 вузлів, `27350d38`).

> **Оновлення 22.10.2026 (вечір):** за рішеннями власника закрито знахідки **1, 2, 3, 4, 9** (див. RELEASE_PLAN §86; n8n `3a319870`). Знахідка 7 — прийнято «станом на дату оновлення даних» (мітка, не вирівнювання статусних дат). Нова знахідка: Owner View S-04 (JS) рахує від ETC_факт, Weekly Render/чат (SQL) — від BAC. Підсумок після закриття: **P0 0 · P1 4 · P2 7**.

## Знахідки

| # | Пріор. | Тип | Де | Еталон | Факт (доказ) | Рекомендація | Рішення від |
|---|---|---|---|---|---|---|---|
| 1 | P1 | SEM | SQL `archi_ready_gap_signal`; вузли `Build Weekly Render HTML`, `WR: Render Report` (п. 3) | `FORMULAS` E-04; Образ результату §4 | **Факт (live SQL):** DEMO-05-АН: витрачено 64,0%, готовність ПМа 40,0%, за прогнозом 51,6%, розбіжність −11,6 п.п. → 🟢; CPI_год = 0,63. Від’ємна розбіжність = оптимістичний ETC ПМа, що приховує перевитрату. Метрика узгодженості, до неї «зелене = краще за план» не застосовується | Фарбувати в обидва боки (≥ 10 п.п. за модулем), підпис «узгодженість прогнозу» (Самоаудит R1) | власник |
| 2 | P1 | SEM | `archi_report_today.acts_to_ev_signal`, п. 7 | `CLAUDE.md` п.7 («відхилення від плану»); `FORMULAS` E-06 | **Факт (live SQL):** 12 з 16 проєктів 🔴 (акти підписуються після стадії, EV росте безперервно). DEMO-04: акти 55,6% контракту, EV 96,5% → 0,58 🔴, хоча акт Р за планом 30.10. Реально прострочені акти за `payment_schedule`: DEMO-03 (П, 16.10), DEMO-05 (П, 10.09), DEMO-06 (П, 09.10) — індекс їх не виділяє | «Акти ÷ план на дату» за `payment_schedule` (Самоаудит R4) | власник |
| 3 | P1 | FORM | `archi_etc_gap_signal` | `FORMULAS` S-04, H-02; EVM (VAC/BAC) | **Факт (live SQL):** база порогу — ETC_факт (залишок бюджету). DEMO-04-АН: Δ +3,0 год = 17,6% залишку, 6,0% BAC → 🔴 (за BAC був би 🟡); DEMO-05: +60,5 год = 4,7% BAC → 🟡 (за BAC 🟢) | База BAC (Самоаудит R2) | власник |
| 4 | P1 | FORM/SEM | п. 3 «Ефективність годин» (E-05) після зняття CPI (§84) | `FORMULAS` E-05, F-10, F-26 | **Факт (live SQL):** CPI_год = E-02÷E-01 і E-05 різняться при ненульовій розбіжності: DEMO-05-АН 0,63 проти 0,81; DEMO-06 0,80 / 0,89; 24-52 1,59 / 1,14. Weekly Render лишився без індексу, не залежного від прогнозу ПМа | Рядок «Ефективність виконання» = CPI_год (Самоаудит R3) | власник |
| 5 | P1 | ARCH | `Build MiniApp Data`; `AN: Attach Block`; SQL `archi_etc_gap_signal` | `TECH_SPEC` §2.1 (A-1), §13 | **Факт (grep):** пороги живуть у 3 місцях: `Build MiniApp Data` (`ETC_RED`, `CPI_RED`…), `AN: Attach Block` (власна копія `rule('cpi_red',0.85)`, `rent_drop_pp`, `unpaid_*`) і нові SQL-функції (S-04 реалізовано двічі: JS і SQL). Переходить із 18.10 #3. `AN: Patch HTML` (заміна за якорями) існує | Один контур: Owner View читає сигнали з SQL; прибрати копію в `AN: Attach Block`; визначити з власником «два місця обчислення» (JS + SQL) у §2.1 | власник |
| 6 | P1 | SEM | `WR: Parse Agent Output` (S-12, 20 п.п.) і `archi_ready_gap_signal` (E-04, 10 п.п.) | `FORMULAS` S-12, E-04; Образ результату §4 | **Факт:** під назвою «Розбіжність готовності» є дві метрики: стадійна (по годинах тієї ж стадії, 20 п.п., лише після підтвердження ПМа) і проєктна (EV% − AC/EAC, 10 п.п.). Ключі `readiness_gap_pp=20` і `wr_ready_gap_pp=10` | Перейменувати E-04, звести в `FORMULAS` | власник |
| 7 | P1 | DATA | `archi_recalc_stages`; `archi_snapshot_evm` | EVM (AC і EV на одну статусну дату) | **Факт (код):** AC = Σ усього `time_log`; готовність і ETC — з останнього знімка. **Факт (live SQL):** годин після звітного тижня зараз 0 (демо-дані) — ефект не спостерігається; у бойовому режимі EAC завищується. C-4: 12 проєктів — звіт 10 днів, DEMO-08 — 31 день; `wr_stale_days` немає | AC на кінець звітного тижня або «станом на» + прапорець старого звіту (Самоаудит R7) | власник |
| 8 | P1 | TXT/SEM | `Build Status Text` | `LAYOUT_STANDARD` п.8; 18.10 #8 | **Потребує перевірки:** вузол містить «CPI»; цього разу текст не перечитував. З 18.10 був відкритий (немає «Станом на», база CPI не названа) | Перевірити/виправити | виконавець |
| 9 | P2 | FORM | SQL `archi_report_today.etc_gap_signal`, `archi_snapshot_history` | `FORMULAS` H-02 | **Факт (live SQL):** DEMO-08 і DEMO-08-АН (готовність 100%): `etc_gap_signal = NULL`. Виняток ховає фінальну Δ завершеного проєкту; після §83 для Δ ≤ 0 зайвий | Прибрати виняток | виконавець |
| 10 | P2 | DOC | `workflows/DEMO_Archi_Agent_Core.json` | `CLAUDE.md` «Після зміни в n8n» | **Факт:** `activeVersionId` = `89f82443`, живий `868f0316`. Причина: поле копіювалось зі знімка до публікації (моя помилка) | **Виправлено цим комітом** | — |
| 11 | P2 | DOC/DATA | `archi_thresholds.note` | `FORMULAS` §6 | **Факт (live SQL):** `wr_ready_gap_pp` — «\|…\|» (за модулем) при чинному `≥` (однобічно); `etc_yellow/etc_red` — «більше плану» (база ETC_факт); `readiness_gap_pp` — інший зміст. Ключі `demo_asof`, `profit_yellow_share`, `plan_fx_uah_usd` код **не читає** (`grep` по 173 вузлах) | `UPDATE note`; прибрати `demo_asof` (18.10 P0 #1 закрито: код ключ не читає) | власник |
| 12 | P2 | DOC | `sql/2026-10-21_evm_readiness_chain.sql`, `…_deviation_colors.sql` | `CLAUDE.md` «оновити репозиторій» | **Факт:** тексти вʼю й функцій у цих файлах застарілі (чинні — `…_deviation_colors2.sql`, `2026-10-22_color_direction.sql`); повного експорту БД у репо немає | У шапки додано «ЗАСТАРІЛО»; експорт `pg_get_viewdef`/`pg_get_functiondef` | виконавець |
| 13 | P2 | DOC | `FORMULAS` E-01 | EVM | **Факт:** підпис «PV за часом» хибний (AC/BAC = AC%) | **Виправлено цим комітом** | — |
| 14 | P2 | DATA | `archi_report_today` | `FORMULAS` F-06 | **Факт (live SQL):** 24-37 і DEMO-02 не мають ETC по 4 стадіях → ETC_прогноз, Δ, «за прогнозом», E-04, E-05 порожні (2 з 17 проєктів) | Ризик покриття; рішення F-06 незмінне | — |
| 15 | P2 | ARCH | `WR: Schedule Reminder (Fri 10:00)` | `TECH_SPEC` §11 D1 | **Факт:** єдиний ізольований вузол, тип `cron` (як 18.10 #16) | Рішення власника | власник |
| 16 | P2 | SEC | 1 вузол, `SECURITY.md`, `workflows/…json` | `SECURITY.md` п.1 | **Факт:** літерал токена в 1 вузлі (18.10: 1), у `SECURITY.md` і JSON; allowlist `304884647` у 4 вузлах; RLS: увімкнено `archi_thresholds`, `monthly_goals`, `payment_schedule`, решта (25 з 28 таблиць `public` без `_bak`) — ні. Нових таблиць не створено. **Стан як у `SECURITY.md`** | Без змін (рішення власника) | власник |

## Перевірено й відповідає (з доказом)

- **Збіг репо з живим:** `versionId` `868f0316…`, 173/173 вузлів, `parameters` без відмінностей, `connections` ідентичні (Python-порівняння).
- **A-3 тригери (live SQL):** 5 тригерів `archi_recalc_*` — `money_log`, `payment_schedule`, `project_metrics`, `time_log`, `wr_weekly_snapshots` (14 подій).
- **A-4 мертві вузли:** лише `WR: Schedule Reminder (Fri 10:00)`.
- **A-2 пороги:** усі 31 ключ `archi_thresholds` проаналізовано; 25 читає код (`Build MiniApp Data`, `AN: Attach Block`, `WR: Parse Agent Output`, `WR: Fetch Project Metrics Static`), 3 (`idx_yellow`, `idx_red`, `wr_ready_gap_pp`) читають лише SQL-функції (за задумом §81–83), 3 (`demo_asof`, `plan_fx_uah_usd`, `profit_yellow_share`) не читає ніхто (знахідка 11).
- **C-3 еталонна звірка (live SQL):** `actual_cost` і `cost_final_forecast` збігаються для всіх 17 рядків; єдина відмінність DEMO-02 `ac_indep 183004` проти `ac_db 183005` (0,5 грн, округлення; як 18.10 #17).
- **R-form:** `python3 scripts/check_report_form.py` — **0 розбіжностей**, нумерація пп. 1–12 у чаті ПМа і Weekly Render.
- **Помилки виконань:** `search_workflow_executions` (`error`, `crashed`) з 18.10.2026 → **0**.
- **Глосарій:** слово «залишок» у вузлах — лише в назвах колонок БД, коментарях коду й забороняючих інструкціях (`Build Request Body`, `WR: Save Weekly Snapshot`, `Build MiniApp HTML` — коментар).
- **Єдине обчислення в Weekly Render і чаті ПМа:** вузли `Build Weekly Render Data/HTML`, `WR: Render Report` лише відображають поля `archi_report_today`/`archi_snapshot_history` (прямі `grep`: порогів і формул у них немає).
- **Без грошових сум у Weekly Render:** поля п. 1–12 — відсотки, години, індекси.
- **CPI відсутній у Weekly Render, чаті ПМа, xlsx** (вузли `Build Weekly Render Data/HTML`, `WR: Render Report`, `Xlsx: Build Rows`, три запити не містять `cpi`); лишається в Owner View, `/status`, `AN:` (за рішенням 22.10).
- **Узгодженість історії й сьогодні:** перевірено 21.10 (§80) для 9 колонок EVM; після змін 22.10 повторно **не** звірялось (вʼю змінювались міграцією `deviation_colors2`).

## Не вдалося перевірити

- Живі екрани Weekly Render і чат ПМа після §83–84: потрібен `initData` Telegram; є лише скріни власника до змін.
- **A-5 (порядок виконання, клас D2):** `connections` не змінювались, але повторно не аналізував.
- Таблиця «показник × контур» (крок 3) — повна не складалась; перевірено лише CPI (за вузлами) і п. 1–12 Weekly Render/чату.
- Вузол `Build Status Text`, `Build MiniApp HTML`, `Build Request Body`: зміст підписів не перечитував (знахідка 8).
- Sub-workflow `K6smBd5xWZLWx9rr`, `RC7HNVlJtuPLtvYV`: JSON у репо немає.
- Маршрутизація Telegram (крок 5): `WR: Determine Route` не змінювався з 18.10 — повторно не простежував.
- xlsx після зміни не завантажувався.

## Зміни відносно попереднього checkpoint (18.10.2026)

- **Закрито:** 18.10 P0 #1 (`demo_asof` — код ключ не читає; рядок у БД лишився); n8n 176 → 173 вузли (зокрема прибрано `WR: Patch Layout`; повний перелік не порівнювався); єдина форма пп. 1–12 (R-form, 0 розбіжностей); помилок виконань 0.
- **Нове:** SQL-шар сигналів (`archi_etc_gap_signal`, `archi_ready_gap_signal`, `archi_idx_signal`, `archi_flow_idx_signal`, `archi_paid_idx_signal`, `archi_snapshot_evm`, `archi_snapshot_metrics`), вʼю `archi_report_today`, `archi_snapshot_history`, `archi_plan_execution`; нові пороги `idx_*`, `wr_ready_gap_pp`; EVM-ланцюжок готовності (E-01…E-07); CPI прибрано з Weekly Render/чату/xlsx.
- **Не змінилось (відкрите з 18.10):** A-1 (`AN: Attach Block`, `AN: Patch HTML`), D1 (`WR: Schedule Reminder`), токен у репо, RLS, відсутність `wr_stale_days`, `Build Status Text` (знахідка 8).
- Детальна методологічна частина: `docs/SELF_AUDIT_EVM_22.10.2026.md`.

## Зміни в репозиторії цього checkpoint

`workflows/DEMO_Archi_Agent_Core.json` (`activeVersionId`), `docs/FORMULAS.md` (E-01), шапки `sql/2026-10-21_evm_readiness_chain.sql` і `sql/2026-10-21_deviation_colors.sql`, `docs/SELF_AUDIT_EVM_22.10.2026.md`, цей файл, `docs/RELEASE_PLAN.md` §85. У n8n і Supabase нічого не змінювалось.
