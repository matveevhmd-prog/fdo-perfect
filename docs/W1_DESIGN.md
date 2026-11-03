# ARCHI — W1: дизайн багатоклієнтності (W1.1, W1.2, W1.6)
Версія 1 · 03.11.2026 · дизайн. **Статус реалізації 03.11.2026: M0–M6 і M5 (n8n) виконано, див. `RELEASE_PLAN` §165; T2–T6 і D2 відкриті.** Позначки: **Факт** (джерело поруч: `live SQL`, код, документ), **[Припущення]**, **Потребує перевірки**. Назви об'єктів нижче — **робочі**; назва в гілці Archi діє лише після погодження власника (`CLAUDE.md` п. 14), див. розділ 8.

## 0. Місце · вплив · борг · масштаб
- **Місце:** потік W1 карти (`ROADMAP_TO_RELEASE.md`), перший на критичному шляху; передує W2, W3, W10, W11. Критерії R-2, R-3, R-12.
- **Що зачіпає:** 14 таблиць Archi (розділ 3), 7 в'ю, 15 функцій `archi_*`/`evm_*`, 5 тригерів `archi_recalc_*`; n8n: 42 вузли core + 3 вузли K6sm/RC7H + 1 вузол `Archi_Protocol_Format_Helper` (`scripts/check_tenant_filter.py`, база 03.11.2026); усі екрани й імпорти.
- **Борг, що закривається:** DDL на кожне повідомлення (`WR: Ensure Mode Table`, `WR: Ensure Plan Table`); інтерполяція `'{{ … }}'` у 21 вузлі; глобальні `rates` і `archi_thresholds`; allowlist Telegram ID у 4 вузлах.
- **Масштаб:** N клієнтів (до 20 проєктів на клієнта, `CLAUDE.md` п. 21); один код, дані розділені `company_id`.
- **Не перевірено:** виконання міграцій (їх ще немає), поведінка n8n при зміні первинних ключів на живих даних, навантаження, ізоляція з боку n8n (тести розділу 6 ще не існують), RLS (відкладено, п. 28).

## 1. Мета від кінця
Реліз-критерій R-2: клієнт бачить лише свої дані — **доведено тестом** (розділ 6), у тому числі з боку n8n, бо n8n підключається роллю `postgres`, яка обходить RLS (`SECURITY.md` п. 11). RLS відкладено рішенням власника (п. 28), тому до першого платного клієнта ізоляцію тримає лише фільтр `company_id` у кожному запиті; отже **кожен запит має бути параметризований і містити `company_id`** — це умова, а не прибирання.

## 2. Рішення, на яких стоїть дизайн
| Рішення | Зміст | Джерело |
|---|---|---|
| OD-1 | Одна база Supabase, `company_id` у таблицях | власник підтвердив 03.11.2026, `CLAUDE.md` п. 29 |
| OD-2 | Ключ проєкту `(company_id, project_id)`; `project_id` — людський код, унікальний у межах клієнта | `CLAUDE.md` п. 27 |
| OD-3 | Ролі лише по компанії, без доступу по проєктах | `CLAUDE.md` п. 27 |
| OD-4 | RLS не вмикати до заведення першого платного клієнта | `CLAUDE.md` п. 28 |
| OD-16 | Оператор FDO бачить усіх клієнтів | `CLAUDE.md` п. 22 |
| OD-25 | Самонавчання шарами: сирі дані ізольовані, між клієнтами лише знеособлені патерни | `CLAUDE.md` п. 28 |
| п. 18 | Усі наявні дані — демо-дані | `CLAUDE.md` п. 18; правило сесії 9 |

## 3. Модель даних
### 3.1 Нові таблиці
- `companies`: `company_id uuid PK`, `code text UNIQUE` (напр. `DEMO`), `name`, `kind` ∈ (`demo`, `client`), `created_at`.
- `user_access`: `telegram_user_id bigint`, `company_id uuid NULL`, `role` ∈ (`owner`, `pm`, `gap`, `executor`, `operator`), `created_at`, `created_by`. Унікальність `(telegram_user_id, company_id)`; обмеження: `role = 'operator'` ⇔ `company_id IS NULL`. Проєктної колонки **немає** (OD-3). Наслідок названо власнику: ПМи клієнта бачать усі його проєкти; виконавця не обмежити проєктом чи розділом на рівні доступу.

### 3.2 Таблиці Archi: що змінюється (Факт: `live SQL` 03.11.2026, ключі з `pg_constraint`)
| Таблиця | Зараз | Стане |
|---|---|---|
| `project_metrics` (18 рядків) | PK `(project_id)`; `parent_project_id` (4 рядки) | `company_id NOT NULL`; PK `(company_id, project_id)`; `parent_project_id` — у межах компанії |
| `time_log` (476), `money_log` (152), `payment_schedule` (56), `meeting_log` (11) | без FK на проєкт | `company_id NOT NULL`; FK `(company_id, project_id)` → `project_metrics` |
| `wr_weekly_snapshots` (101) | UNIQUE `(project_id, week_start)` | UNIQUE `(company_id, project_id, week_start)`; FK |
| `wr_plan_items` (467) | UNIQUE `(project_id, week_start, item_number)` | UNIQUE з `company_id`; FK — **заблоковано 245 рядками-сиротами** (розділ 7) |
| `evm_packages` (100) | FK `project_id` → `project_metrics(project_id)`; UNIQUE `(project_id, baseline_no, package_code)` | `company_id`; FK складений; UNIQUE з `company_id` |
| `evm_package_done` (0) | FK `package_id` → `evm_packages(id)` | `company_id` (денормалізовано, для фільтрів і майбутнього RLS) |
| `kp_log` (11) | `telegram_user_id`, без проєкту | `company_id` (компанія автора запису) |
| `rates` (7) | PK `(posada)` — глобально | PK `(company_id, posada)`; ставки на клієнта (W3.6) |
| `archi_thresholds` (25 рядків) | PK `(key)` — глобально | значення за замовчуванням `company_id IS NULL` + перевизначення на клієнта; пошук `COALESCE(перевизначення, за замовчуванням)` (W1.5) |
| `archi_bot_mode_state` (1) | PK `(session_id)` = Telegram-чат | PK лишається; + `company_id` (активна компанія; для оператора — обрана) |
| `archi_wr_inbox` (0) | RLS так; `session_id`, `project_id` | + `company_id` |

**Не чіпаються (не Archi або чужий продукт у тій самій базі):** `jarvis_*`, `shift_*`, `bot_*`, `chat_history_clean`, `n8n_bot_logs`, `reports`, `response_trace`, `monthly_goals`, `archi_representative_chat_history` (Representative Bot — не чіпати). `archi_bot_full_history`, `archi_bot_learnings`, `archi_bot_semantic_memory` (8 126 рядків) — не тенантні; шар знань W10 буде окремою таблицею з `company_id`.

### 3.3 В'ю, функції, тригери
- В'ю `archi_report_today`, `archi_snapshot_history`, `archi_weekly_progress`, `archi_plan_execution`, `evm_classic_today`, `project_metrics_live`, `rates_coverage_check`: додати `company_id`, з'єднання за обома ключами.
- Функції з `p_project text`: `archi_recalc`, `archi_recalc_stages`, `archi_recalc_visit`, `archi_acts_plan`, `archi_snapshot_metrics`, `archi_snapshot_evm`, `evm_classic_at` — нова перша змінна `p_company uuid`; усі `JOIN` і `WHERE` за `(company_id, project_id)`. Сигнальні функції (`archi_vac_signal`, `archi_idx_signal`, `archi_flow_idx_signal`, `archi_paid_idx_signal`, `archi_ready_gap_signal`, `archi_etc_gap_signal`) читають `archi_thresholds` через значення компанії.
- Тригери `archi_recalc_time/money/wr/schedule/plan`: `archi_recalc_trg()` передає `NEW.company_id`.
- Факт: `archi_recalc_stages` об'єднує `time_log`, `money_log`, `wr_weekly_snapshots`, `payment_schedule` лише за `project_id`, а `rates` — лише за `posada` (код). Без `company_id` два клієнти з однаковим кодом проєкту змішали б години й ставки.

## 4. Контекст компанії в n8n
- **Резолвер компанії** — перший вузол кожного входу: `Telegram Trigger` і три webhook-и (Owner View, Weekly Render, xlsx; після `Validate InitData`). Запит: `user_access` за `telegram_user_id`. Вихід: `company_id`, `role`.
- Немає запису → «доступ не надано» (закриває бот, відкритий для будь-кого, `SECURITY.md` п. 7 — потребує рішення власника, розділ 8, D5). Замінює зашитий allowlist у 4 вузлах.
- Оператор: активна компанія береться з `archi_bot_mode_state.company_id`; вибір — клавіатурою «клієнт → проєкт».
- Кожен Postgres-вузол на об'єктах Archi: `queryReplacement` з `company_id`; `WHERE`/`ON CONFLICT` містять `company_id`; запис `company_id` явний (без `DEFAULT` після завершення міграції). Зараз `company_id` у 0 з 46 вузлів (код, `scripts/check_tenant_filter.py`).
- Ключі чернеток: `n8n_chat_histories.session_id = '<chat>_import_<project>'` (вузли `Import: Reset Draft`, `Import: Clear Draft After Final`) — додати компанію: `<chat>_<company>_import_<project>`, інакше оператор з однаковим кодом проєкту у двох клієнтів змішає чернетки.
- Клас дефекту D2 (читання `$('…')` з іншої гілки): резолвер викликається на початку кожної гілки, а не береться з сусідньої.

## 5. Порядок міграції (розширення → перемикання → стиснення), кожен крок з відкатом
| Крок | Дія | Відкат / перевірка |
|---|---|---|
| M0 | Резервні копії таблиць Archi (`_bak_<дата>_<таблиця>`, як раніше) | видалити копії |
| M1 | `companies`, `user_access`; рядок `DEMO` (`kind='demo'`) | `DROP` двох таблиць |
| M2 | `company_id` nullable з `DEFAULT` = id `DEMO`; заповнення наявних рядків (усі — демо, п. 18) | `DROP COLUMN` |
| M3 | Нові унікальні індекси `(company_id, project_id…)` **поруч** зі старими первинними ключами | `DROP INDEX` |
| M4 | Нові версії функцій і в'ю з `company_id` поряд зі старими; тригери перемкнено | повернути старі функції |
| M5 | Оновлення n8n (W1.6): резолвер, параметри, `ON CONFLICT (company_id, …)`, K6sm і RC7H, прибрати вузли DDL | ID відкату n8n; `scripts/check_tenant_filter.py --strict` = 0 |
| M6 | Стиснення: `NOT NULL`, прибрати `DEFAULT`, прибрати старі PK/UNIQUE, додати складені FK | відновлення зі старого індексу |
| M7 | Тест ізоляції (розділ 6) | — |
| M8 | RLS — **відкладено** (п. 28) | — |

**Чому M3 передує M5:** вузли використовують `ON CONFLICT (project_id)` (код): core `WR: Save Weekly Snapshot` — `(project_id, week_start)`, `WR: Save Next Week Plan` — `(project_id, week_start, item_number)`; K6sm `Commit Plan`, `AN: Commit Visit Plan` і RC7H `Write Contract URL` — `(project_id)`. Це 5 операторів, які перестали б працювати після заміни ключів. Ще 10 вузлів режиму (`WR: Reset Mode`, `K: Save Mode` та інші) використовують `ON CONFLICT (session_id)`, ключ `archi_bot_mode_state` лишається, їх це не зачіпає. Заміна ключів без оновлення вузлів зупинила б запис плану, знімків і договору. `DEFAULT` в M2 дозволяє старим вузлам писати рядки до M5.

## 5a. M5: правила переписування n8n (з аналізу коду 03.11.2026)
- **Входи:** 4 (`Telegram Trigger`, `MiniApp Data Webhook`, `Weekly Render Data Webhook`, `Xlsx Export Webhook`). Кожен із 42 Postgres-вузлів core на об'єктах Archi досяжний рівно з одного входу; виняток — `Fetch Meeting Log (Chat)` (Telegram і Owner View): для нього вираз бере компанію з того резолвера, що виконався.
- **Резолвер на вході:** `Postgres Resolve Company` → `If Has Access` → `Code Attach Company` (додає `company_id`, `role` до елемента, зберігаючи поля тригера). Для вебхуків резолвер стоїть після `Is Valid InitData`; гілка «відмова» веде в наявні `Respond … Unauthorized`; для Telegram — повідомлення «доступ не надано».
- **Факт:** `Validate InitData`, `WR-Render: Validate InitData`, `Xlsx: Validate InitData` не повертають Telegram-ID користувача (повертають лише `valid`, `hashValid`, `fresh`, `member`) і перевіряють зашитий `ALLOWED = ['304884647']`. Для резолвера треба додати `userId` у вихід, а перевірку `ALLOWED` замінити на `user_access` (W1.2).
- **Категорії запитів:** (A) режим чату `archi_bot_mode_state` — ключ `session_id` (Telegram-чат), не змінюється, ізоляція за чатом; (B) два вузли DDL (`WR: Ensure Mode Table`, `WR: Ensure Plan Table`) → `SELECT 1`; (C) видалення чернеток за `session_id` — `company_id` у ключі чернетки (§4); (D) читання `project_metrics`, знімків, в'ю, журналів — `WHERE company_id = $N`; (E) вставки `time_log`, `money_log`, `meeting_log`, `kp_log`, `wr_plan_items`, `wr_weekly_snapshots`, `archi_wr_inbox` — явний `company_id`, `ON CONFLICT` зі складеним ключем (потрібен M3). Параметр `company_id` — через `queryReplacement`, у наявних масивах додається останнім.
- **K6sm і RC7H:** ядро передає `company_id` у виклик; вузли `Commit Plan`, `AN: Commit Visit Plan`, `Write Contract URL` пишуть його й використовують `ON CONFLICT (company_id, project_id)`.
- **Порядок залежностей:** M5 після M3 (потрібні складені індекси для `ON CONFLICT`) і M4 (в'ю мають `company_id`). D2 (сироти) потрібне лише до M6 (складений FK), не до M5.

## 6. Тест ізоляції (критерій R-2)
| Тест | Що перевіряє | Стан |
|---|---|---|
| T1 статичний | `python3 scripts/check_tenant_filter.py --strict`: у кожному Postgres-вузлі на об'єктах Archi є `company_id`. Додати правило: жодної інтерполяції `{{ }}` у запиті на цих об'єктах | скрипт є; база: 46 вузлів без `company_id` (core 42, K6sm 2, RC7H 1, Protocol Format Helper 1) |
| T2 динамічний | дві тестові компанії A і B з **однаковими кодами проєктів** і різними значеннями; для кожного запиту, в'ю, функції в контексті A немає жодного рядка B і навпаки; оператор бачить обидві | не написано; виконувати в транзакції з відкатом [Припущення: `execute_sql` підтримує транзакцію — Потребує перевірки] |
| T3 колізії ключів | `ON CONFLICT` у A не змінює рядок B з тим самим кодом | не написано |
| T4 replay | `scripts/replay/` Owner View і Weekly Render для A і B; порівняння з очікуваним | скрипти є, дані ізоляції немає |
| T5 мутаційний | прибрати фільтр у копії запиту → T1/T2 мають впасти | не написано |
| T6 сесії | оператор перемикає компанію: чернетки й режими не змішуються | не написано |
R-2 вважається виконаним лише після T1–T6.

## 7. Факти, що вплинули на дизайн
| Факт | Джерело |
|---|---|
| Сироти: 245 рядків `wr_plan_items` без проєкту в `project_metrics` (ID `ARCH-…` 13 проєктів, `ARCH2-…` 11 проєктів, тижні 07.09–19.10.2026); у `time_log`, `money_log`, `payment_schedule`, `meeting_log`, `wr_weekly_snapshots`, `evm_packages` сиріт 0 | `live SQL` 03.11.2026 |
| Усі наявні дані — демо; 4 проєкти бюро (22-24, 24-11, 24-37, 24-52) переведені в демо | `CLAUDE.md` п. 18, правило сесії 9 |
| `project_metrics`: 18 рядків (14 стадій + 4 АН), 4 із `parent_project_id` | `live SQL` |
| Вузли без таблиць, але з `project_id` у ключі: `Import: Reset Draft`, `Meeting: Reset Draft`, `Import/Meeting/WR: Clear Draft After Final` (видаляють з `n8n_chat_histories` за `session_id`) | код core |
| `rates` і `archi_thresholds` глобальні; сигнальні функції SQL мають резервні пороги, що відрізняються від БД (`archi_vac_signal` 0,10/0,05) | код, `live SQL` |

## 8. Рішення дизайну (D1, D2, D4, D5 — власник 03.11.2026; D3 — за правилом сесії 9; D6 відкрито)
| ID | Питання | Варіанти | Рекомендація |
|---|---|---|---|
| D1 ✅ погоджено | Назви об'єктів Archi (`CLAUDE.md` п. 14): `companies`, `company_id`, `user_access` | погодити як є / запропонувати свої | `company_id` назвав власник (п. 17); `companies`, `user_access` запропоновані Claude — погодити або змінити |
| D2 ✅ варіант A | 245 сиріт `wr_plan_items` (`ARCH-…`, `ARCH2-…`) — блокують складений FK | A: перенести в `wr_plan_items_legacy` з відкатом; B: перейменувати на поточні ID (ризик дублікатів ключа); C: видалити | A (дані не губляться, FK можливий; правило 18: зміна даних — пакетом із відкатом, за «так») |
| D3 ✅ варіант A (за п. 18 і правилом 9) | До якої компанії належать наявні дані | A: одна `DEMO`; B: `DEMO` + окрема компанія бюро для 4 проєктів | A (п. 18, правило 9: усе демо) |
| D4 ✅ варіант A | Пороги й параметри на клієнта (W1.5) | A: значення за замовчуванням + перевизначення на клієнта; B: повна копія на клієнта | A (менше дублювання, зміна методології діє на всіх) |
| D5 ✅ варіант A | Невідомий користувач Telegram | A: відмовити (тільки `user_access`); B: дозволити читання | A (закриває `SECURITY.md` п. 7; рішення власника) |
| D6 відкрито | Де виконувати динамічний тест T2 | A: транзакція з відкатом у робочій базі; B: гілка Supabase (платна, потрібна згода на вартість) | A, якщо транзакції в `execute_sql` працюють; інакше B |

## 9. Що далі
Після рішення D6: міграції M0–M2 і M3–M4 (кожна — `apply_migration` + файл і відкат у `sql/`), далі M5 (зміна n8n за правилами `CLAUDE.md`), M6, T1–T6. Зміна живої системи — лише після явного «так».
