# Аудит коду проти документації — 05.11.2026

Знімок: git `09cbc26` (main, гілка аудиту `claude/code-audit`), core `a4c89c3c-3892-40d0-91e6-7e9ba5eb49d9`, 191 вузол, Supabase `bxawceksdkqlbkdgjvyz` (SQL 2026-11-05 05:48 UTC, live).
Режим: лише читання. n8n MCP: `get_workflow_details`, `search_workflows`, `search_workflow_executions`. Supabase MCP: лише `SELECT`/`pg_get_functiondef`/`pg_get_viewdef`/`pg_catalog`.
Підсумок: **P0 1 · P1 5 · P2 8**; BR перевірено 69 з 69 на рівні «статус документа проти наявності реалізації»; поглиблено (код/SQL) — 24 з 69 (усі BR-50…BR-56, BR-08, BR-05, BR-12, BR-13, BR-28, BR-29, BR-42, BR-62, BR-65, BR-81…BR-89, BR-90); формул (ID з `FORMULAS` §2–§5) порівняно **не всі** — див. «Не вдалося перевірити».

## Знахідки

| № | Тип | Рівень | Де | Що в документі | Що в коді | Доказ | Пропозиція |
|---|---|---|---|---|---|---|---|
| 1 | MISSING | P0 | `archi_morning_brief`, вузол `Validate And Render` (workflow `J3Oqcaa2YBEsVSng`) | `02` BR-51 ✅: «стан портфеля, топ-5 дій…»; `CLAUDE.md` п. 32 і `ROADMAP` W5.7: «стан портфеля + план на день» | JSON брифінгу має ключі `as_of, actions, company_id, horizon_7d, projects_total, data_updated_at, candidates_total`; блоку стану портфеля (кількість 🔴/🟡/🟢 тощо) немає ні в SQL, ні в тексті, який збирає `Validate And Render` (шапка → дії → «Горить за 7 днів» → «Головне») | live SQL `select jsonb_object_keys(archi_morning_brief(<DEMO>))` (05.11.2026); код вузла `Validate And Render` | Або знизити BR-51 до 🟡 з названою прогалиною, або додати блок стану в SQL і текст. Рішення — власник |
| 2 | SEM | P1 | вузли `Build MiniApp Data`, `AN: Attach Block` | п. 15, п. 31: пороги лише в `archi_thresholds`; жорстких порогів у коді не має бути | `rule('<ключ>', <запасне>)` має запасні значення зі старої методології: `etc_red 0.10`, `etc_yellow 0.05`, `rent_drop_pp 5`, `rent_drop_pp_red 10`, `profit_*_pct 5/10`, `cpi_red 0.85`, `cpi_yellow 0.95`, `idx_red 0.7`, `idx_yellow 0.9`, `slip_red_days 14`; у БД ті самі ключі = 0 або 1. 27 розбіжностей запас↔БД (скрипт-порівняння живого JSON з `archi_thresholds`) | `rule()` у `Build MiniApp Data` повертає запас, якщо `rules` порожні (`toNum(RULES[k]) === null`) | Якщо `archi_rules` не повернув ключ (збій, нова компанія без рядків) — Owner View тихо повертається до порогів до п. 15, жовтий з'являється. Прибрати запасні значення; при відсутності ключа — явна помилка (входить у W1.8) |
| 3 | SEM | P1 (потребує перевірки) | `Build MiniApp Data` | п. 15: жовтого для відхилень від плану немає; виняток лише неоплата, ймовірність документації, дні блокера | жовтий ще присвоюється: «Готовність за оцінкою ПМ не збігається з годинами» (`readiness_gap_pp = 20`); «Оптимістичний прогноз ПМа» (`cls.etc 'green'→'yellow'`); `slip > 0 → 'yellow'` (недосяжно при `slip_red_days = 0`, мертва гілка); мітка групи «Ефективність 1–1 — на межі» при `cpi_red = cpi_yellow = 1` | живі пороги `archi_thresholds`; рядки коду з `yellow` у `Build MiniApp Data` (62 входження) | Власник вирішує, чи ці два сигнали — «відхилення від плану» (тоді 🔴/🟢) чи окремі попередження. Мертву гілку `slip` і порожню мітку прибрати |
| 4 | DOC | P1 | `README.md:25`, `docs/HANDOVER_CTO.md:33,55`, `docs/START_PROMPT_HQ.md:25`, `docs/ARCHI_TECH_SPEC_v3_1.md:217` | `activeVersionId 40abff53…`, 179 вузлів, «експорт 30.10.2026» | Живий і експорт: `versionId a4c89c3c…`, 191 вузол. `README.md:3` вже каже 191 (внутрішня суперечність файлу). `START_PROMPT_HQ.md:25` велить звіряти live з `40abff53…` — штаб порівнюватиме з хибною базою | live `get_workflow_details` + `workflows/DEMO_Archi_Agent_Core.json` | Оновити чотири місця; `check_docs.py` перевіряє лише `a4c89c3c` у пакеті, цей клас не ловить — додати перевірку «жодного іншого 8-символьного versionId core» |
| 5 | TENANT | P1 | вузли `WR: Read Mode`, `WR: Write Project Mode`, `WR: Write Reference Mode`, `WR: Reset Mode`, `Import: Write Project Mode`, `Meeting: Write Project Mode`, `Doc Intake: Write Mode`, `Doc Intake: Reset Mode After File/Link`; ключі `n8n_chat_histories.session_id` | `03` §4: `archi_bot_mode_state.company_id` допускає NULL (відомо); крок 3 промпту: ключі чернеток і пам'яті мають містити `company_id` | Вузли інтерполюють `chat.id` і пишуть/читають `archi_bot_mode_state` без `company_id` у `WHERE`/`INSERT`; `session_id` чернетки = `<chat>_wr_<project_id>` без компанії. `scripts/check_tenant_filter.py` дає «0 без company_id» бо в його переліку таблиць Archi немає `archi_bot_mode_state` і `n8n_chat_histories` — скрипт хибно заспокоює | live JSON (21 Postgres-вузол з `{{ }}`), `check_tenant_filter.py` вивід | За правилом промпту запис без `company_id` = P0; знижено до P1, бо таблиця свідомо виключена в `03` §4, а `chat.id` унікальний на користувача. Для 2+ клієнтів з одним ПМом у двох компаніях — колізія `project_id`. Додати таблиці в скрипт; ключ чернетки — з `company_id` (потік W1) |
| 6 | DOC | P1 | `docs/CTO_CHECKPOINT_PROMPT.md` C-3 | еталонна звірка F-02/F-13/F-15 | запит з'єднує `time_log`, `project_metrics`, `rates`, `money_log` лише за `project_id`; після W1 ключ `(company_id, project_id)` → при другій компанії дає перехресні суми | текст запиту, рядки 94–104 | Додати `company_id` в усі `JOIN`/`GROUP BY` (виправлену версію виконано в цьому аудиті, результат нижче) |
| 7 | DRIFT | P2 | `workflows/DEMO_Archi_Agent_Core.json`, `Archi_Koshtorys_Ingest_K6sm.json` | експорт = живе | `versionId` збігаються (core `a4c89c3c`, K6sm `23c5765e`), але `activeVersionId` у файлах старий: core `83f65552…` проти live `a4c89c3c…`; K6sm `cf904641…` проти live `23c5765e…`. Вузли й `connections` core ідентичні живим; параметри відрізняються лише в `M: Send Project Picker` (заглушка токена) | порівняння живого JSON з файлом (скрипт) | Переекспортувати з коректним `activeVersionId` |
| 8 | DRIFT | P2 | `workflows/Archi_Morning_Brief.sdk.ts` | експорт брифінгу | live `versionId = activeVersionId = ae7e4e3b-eaa7-4ff6-b108-c6edec0311f4`, 10 вузлів; у `.sdk.ts` ідентифікатора версії немає, побайтове порівняння неможливе. Текст `Build LLM Request` у файлі й у live збігається за початком (модель `claude-sonnet-4-6`) | live `get_workflow_details` | Записати версію в заголовок файлу |
| 9 | DOC | P2 | `docs/ARCHI_TECH_SPEC_v3_1.md:283` | інвентар Postgres-вузлів 47: з параметрами 13 / з інтерполяцією 21 / статичних 13 (28.10) | live 05.11: 51 вузол — з параметрами **28**, з інтерполяцією **21**, статичних **2** | live JSON | Оновити інвентар або позначити «станом на 28.10» |
| 10 | TXT | P2 | вузол `Build Request Body` | п. 1: «залишок» заборонено; дозволено лише в назвах колонок БД і заборонних інструкціях | у шаблоні відповіді чату є фраза «Даних немає: залишку коштів на рахунках у системі немає» — слово в значенні залишку на рахунку, у тексті для користувача | пошук у live JSON вузла | Замінити формулювання («залишку коштів» → «грошей на рахунках») |
| 11 | DATA | P2 | `project_metrics.cost_final_forecast`, проєкт `24-52` | F-13 | незалежний розрахунок 2 283 122, у БД 2 283 123 (різниця 1 грн, округлення). Решта 16 проєктів збігаються; `24-37`, `DEMO-02` — прогнозу немає, `cf` = NULL в обох | live SQL (виправлений C-3) | Без дії |
| 12 | SEM | P2 | `archi_thresholds` | 31 ключ, кожен має споживача | без споживача ні в SQL, ні в n8n: `demo_asof`, `plan_avg_project_hours`, `plan_fx_uah_usd`; `profit_yellow_share` не знайдено ні в SQL, ні в n8n. `wr_ready_gap_pp` читає лише SQL (`archi_ready_gap_signal`). `company_thresholds` порожня (перевизначень немає — не дефект) | зіставлення ключів з визначеннями 31 функції/в'ю й 191 вузла | Позначити в `FORMULAS` §6 або видалити |
| 13 | DEAD | P2 | `WR: Schedule Reminder (Fri 10:00)` | `TECH_SPEC` D1: відомий; BR-29 ⬜ | підтверджено: `cron` п'ятниця 10:00 Europe/Kyiv, вихідних з'єднань немає. Нових мертвих вузлів немає (інші без вхідних — підвузли LangChain `WR: OpenAI Chat Model`, `*: Postgres Chat Memory`, підключені через `ai_*` — [Припущення], зв'язки `ai_*` не перевірялись) | `connections` live | Відомо; не нова знахідка |
| 14 | SEC | P2 | `SECURITY.md` п. 7б–11 і далі | нові таблиці/в'ю з RLS без політик | підтверджено live: `companies`, `user_access`, `company_thresholds`, `owner_prefs`, `archi_wr_inbox`, `archi_thresholds`, `payment_schedule`, `evm_*` — RLS увімкнено, політик 0; `project_metrics`, `time_log`, `money_log`, `meeting_log`, `kp_log`, `rates`, `wr_plan_items`, `wr_weekly_snapshots` — вимкнено. `SECURITY.md` згадує `archi_thresholds` (1 раз), але не згадує `monthly_goals` (RLS увімкнено, таблиця не частина ARCHI) | live `pg_class.relrowsecurity`, `pg_policies` | Дописати в `SECURITY.md`; RLS не змінювати (п. 28) |

## Трасування вимог (Крок 1)
Охоплено 69 BR. Таблицю дано для вимог, перевірених за кодом чи SQL; решта — лише відповідність статусу наявності/відсутності реалізації (позначено «лише наявність»).

| BR-N | де в коді | статус документа | статус за кодом | висновок |
|---|---|---|---|---|
| BR-05 | в'ю `archi_weekly_progress` | ✅ OV; ⬜ WR | в'ю є | збігається |
| BR-07 | колір у `Build MiniApp Data`, `AN: Attach Block` | 🟡 | розрахунок кольору поза SQL, запасні пороги (знах. 2) | 🟡 правдиво |
| BR-08 | `archi_*_signal`, `Build MiniApp Data` | ✅ | жовтий лишився в n8n (знах. 3) | ✅ заявлено завищено — знах. 3 |
| BR-12 | `Build MiniApp Data` | ✅/🟡 | лише наявність | не перевірено глибше |
| BR-13 | «Станом на» у `Build Request Body`, `Build Status Text`, `WR: Build Status Text`, `WR: Render Report`; `data_updated_at` у `Build MiniApp Data`, `Build Weekly Render Data`, `Xlsx: Build Rows` | 🟡 | дата в цих вузлах є; наявність саме підпису «Станом на» на екранах Owner View/Weekly Render не підтверджена (його немає в `Build MiniApp HTML`, `Build Weekly Render HTML`) | 🟡 правдиво |
| BR-24 | `WR: Parse Agent Output` | ✅ | `node tests/wr_parse_agent_output/run.js`: 29 пройдено, 0 провалено | збігається |
| BR-28 | `Xlsx: Build Rows` | ✅ | грошових полів немає (пошук `contract_amount`, `actual_cost`, `grn`) | збігається |
| BR-29 | cron без з'єднань | ⬜ | вузол є, не працює | збігається |
| BR-42 | `Build Request Body` | ✅ | промпт велить відповісти «Даних немає» | збігається |
| BR-50 | `owner_prefs` (08:30, пн–пт, Europe/Kyiv, `last_sent_on` NULL), `Find Due Owners` | ✅ | розклад і запит є; **реальної відправки ще не було** (`last_sent_on` NULL; 12 запусків за добу, усі `success`, 0,35 с — нікому відправляти) | реалізація є, наживо не підтверджено |
| BR-51 | `archi_morning_brief`, `Validate And Render` | ✅ | блоку стану портфеля немає | **знах. 1** |
| BR-52 | `advice` у SQL, `message` у LLM | ✅ | адресат за роллю, дія, готовий текст є | збігається |
| BR-53 | `Validate And Render` (`numbersOk`, `itemOk`, `fallback`); `onError: continueRegularOutput` на `Call Anthropic` | ✅ | перевірка чисел кодом, запасний текст при збої LLM | збігається |
| BR-54 | SQL читає `project_metrics`, `payment_schedule`, `meeting_log`, `wr_weekly_snapshots` | ✅ | нових таблиць для даних немає (`owner_prefs` — налаштування) | збігається |
| BR-55 | `sub_blocked`, вага 120, регулярні вирази; у живих даних — ранг 3 (`DEMO-08`) | ✅ | збігається | збігається |
| BR-56 | `CASE kind … advice` в SQL | ✅ | в SQL | збігається |
| BR-81 | `sql/tests/w1_isolation_T2_T3.sql` | 🟡 тест БД ✅; n8n ⬜ | у live одна компанія (`DEMO`) — динамічно перевірити неможливо | 🟡 правдиво |
| BR-82/83 | `user_access` (CHECK: `operator` ⇔ `company_id IS NULL`), `Resolve Company`, `Has Access` ×4 | 🟡 | усі 4 входи мають `Resolve Company` → `Has Access` до даних; у Telegram не прогнано | 🟡 правдиво |
| BR-84 | `Resolve Company (Telegram)`: `COALESCE(u.company_id, ms.company_id, найстарша компанія)` | ✅ модель | при 2+ компаніях оператор без режиму бачить лише найстарішу | ✅ «модель» — прийнятно, відмітка |
| BR-85 | `archi_thresholds` 31 + `company_thresholds` (0 рядків), `archi_rules`, `archi_threshold` | ✅ | зберігання є; споживання пороговий шлях частково в n8n (знах. 2, 12) | збігається щодо зберігання |
| BR-86 | токен у `M: Send Project Picker` | ⬜ | рівно 1 вузол з літералом токена | збігається |
| BR-89 | `companies`: `DEMO`, `kind='demo'` | ✅ | збігається | збігається |
| BR-90 | `tests/wr_parse_agent_output` | ⬜ | є один тест | збігається |
| інші ✅ / 🟡 / ⬜ | — | — | лише наявність/відсутність реалізації | не перевірено глибше |

## Розрахунки поза SQL (Крок 2)

| Місце | Що рахує | Чи є в SQL | Вузол карти |
|---|---|---|---|
| `Build MiniApp Data` | `worst`, `cls.*` (ETC, rent, profit, received, acts, cpi, cpiH), `idxSig`, `ppSig`, `heroCls`, `docCls`, `bCls`, `slip` | частково (`archi_etc_gap_signal`, `archi_idx_signal`, `archi_vac_signal`, `archi_plan_execution`); решта лише в n8n | W1.8 (борг A-1, D14) |
| `Build MiniApp Data` | порогові сигнали: неоплата (`unpaid_*`), `doc_prob_*`, `block_red_days`, `readiness_gap_pp`, `opt_*`, `slip_red_days`, `plan_year_*` | немає в SQL | W1.8 |
| `AN: Attach Block` | `rent_drop_pp(_red)`, `cpi_*`, `unpaid_*` для договорів АН | немає | W1.8 |
| `Build MiniApp HTML` | відображення кольору | n/a | — |
| `Build Weekly Render Data/HTML`, `Xlsx: Build Rows` | колір і порогів не рахують (береться з SQL) | так | — |
| `Validate And Render` (брифінг) | перевірка чисел, запасні тексти | n/a (за дизайном) | W5.7 |

Новий відносно `RELEASE_PLAN` випадок — **запасні пороги** в `rule()` (знах. 2). Решта відповідає відомому боргу W1.8.

## Перевірено й відповідає (з доказом)
- Кількість вузлів core: live 191 = експорт 191; множини імен однакові; `connections` ідентичні; `executionOrder v1` (live JSON `settings`).
- Вузлів Postgres 51: 28 з параметрами, 21 з інтерполяцією, 2 статичних; DDL-вузлів (`CREATE/ALTER/DROP`) 0 — `WR: Ensure Mode Table`/`Ensure Plan Table` відсутні.
- `Telegram Trigger` приймає лише `message` (`updates: ["message"]`); обробки групових чатів немає (W10 не реалізовано, збігається з документом).
- Чотири входи (Telegram, Owner View, Weekly Render, xlsx): кожен шлях до даних проходить `Resolve Company` → `Has Access`; сторінки-вебхуки `*Page Webhook` віддають лише статичний HTML. `Validate InitData` ×3 перевіряє `auth_date`, `MAX_AGE_SECONDS = 86400`.
- Усі 31 функція `archi_*`/`evm_classic_*` — `SECURITY INVOKER`; в'ю `evm_classic_today` має `security_invoker=true`; інші 6 в'ю — без цього параметра (відомо, `SECURITY.md` 7б–11).
- Секрети: токен Telegram `\d{8,}:AA…`, `sk-`, `AIza…`, JWT, приватні ключі в `workflows/ sql/ docs/ scripts/ tests/` та кореневих `.md` — 0 збігів. Живий core: літерал токена рівно в 1 вузлі `M: Send Project Picker` (відомий ризик, п. 25); решта вузлів 190 без літералу.
- Weekly Render: у `Build Weekly Render Data/HTML` і `Xlsx: Build Rows` немає `contract_amount`, `actual_cost`, `грн`, `UAH`, `fmtUAH`.
- `.pyc` у git немає.
- Дані: F-02 (`actual_cost`) збігається з незалежним розрахунком по всіх 18 проєктах; F-13 і F-15 — по 16 проєктах з прогнозом (розбіжність 1 грн лише в `24-52`, знах. 11).
- `wr_plan_items_legacy` у БД немає (`information_schema`), як і заявляє `03` §4 (D2 не виконано).
- Брифінг: ранги за ваговими правилами працюють (live: `blocker` ×2, `sub_blocked`, `act_due` ×2; не більше 2 дій на проєкт — `rp <= 2`, `LIMIT 5`).

## Результати скриптів
| Скрипт | Результат |
|---|---|
| `python3 scripts/check_docs.py` | помилок 0, попереджень 0; пунктів `CLAUDE.md` 32; розділів `RELEASE_PLAN` 177; вузлів core 191 (`a4c89c3c`) |
| `python3 scripts/check_handover.py` | PASS 14 · WARN 0 · FAIL 0 |
| `python3 scripts/check_report_form.py` | розбіжностей 0 |
| `python3 scripts/check_tenant_filter.py` | «без company_id: 0» — **але перелік таблиць неповний** (знах. 5) |
| `node tests/wr_parse_agent_output/run.js` | пройдено 29, провалено 0 |

## Не вдалося перевірити (чому)
- **Формули за ID.** Не зіставлено слівно кожен ID `FORMULAS` §2–§5 (E-, F-, S-, P-, PX-, H-) з тілом `archi_recalc`, `archi_recalc_stages`, `archi_recalc_visit`, `evm_classic_*` і в'ю. Тіла збережено (31 функція, 7 в'ю), перевірено лише пороги, `SECURITY INVOKER`, споживачів ключів і C-3 (F-02, F-13, F-15). Причина: обсяг; сигнали й кольори не прогнано на межових значеннях.
- **Динамічна ізоляція клієнтів** (BR-81, R-2): в БД одна компанія `DEMO`, другого Telegram-акаунта немає; `Has Access` не прогнано в Telegram. Тести T4–T6 не виконано. Запис тесту в БД заборонено режимом «лише читання».
- **Реальна відправка ранкового брифінгу:** `last_sent_on` NULL, вікно 08:30 Києва ще не настало; не бачив жодного виконання з реальним листом і `Send Brief`.
- **Верстка «стовпчиком»** (п. 4): 5 вузлів `Send …` і `WR: Send Project Confirmation` не переглянуто.
- **Q1–Q10** у 4 місцях збігаються: не звірено.
- **Маршрутизація кнопок** (`WR: Determine Route` → `Hard Logic Engine` → `Route`): шляхи не простежено.
- **`Build MiniApp Data` / `AN: Attach Block` проти `FORMULAS`:** знак і колір по кожному показнику не звірено рядок у рядок; лише пошук `yellow`.
- **Параметризація 6 вузлів** із вільним текстом (`TECH_SPEC` §10) і вміст 21 інтерпольованого вузла на ін'єкцію: переглянуто 6 з 21; решту не відкривав.
- **Дані виконань n8n** не відкривав (секрети): лише статуси.
- Екрани Owner View / Weekly Render наживо в Telegram; `Build MiniApp HTML` (чи є «Станом на» у виводі).
- Чотири інші workflow (`LK4tBGMPiwIgpoki` Protocol Format Helper та ін.) — не порівнювались із файлами.

## Зміни відносно попереднього аудиту
Попередній: `docs/CTO_CHECKPOINT_03.11.2026.md`; повного порівняння знахідок не виконано. Нове з 03.11: workflow «ARCHI: Morning Brief» (знах. 1, 8), `owner_prefs`, `company_thresholds` (порожня), core 179 → 191 вузол (знах. 4, 9). Підтверджено без змін: D1 (мертвий cron), літерал токена в 1 вузлі, відсутність `wr_plan_items_legacy`.

## Статус виправлень (06.11.2026; рішення власника «1А, 2А, 3А, 4А»)
Знімок аудиту (git `09cbc26`, core `a4c89c3c`) застарів: до 06.11 у `main` злито PR #139 і наступні (core тепер `978db8b8`, 193 вузли; Morning Brief — `cb4b50e8`).

| Знахідка / рішення | Статус на 06.11.2026 | Доказ |
|---|---|---|
| 1 / 1А: стан портфеля в брифінгу (BR-51) | **Вже виконано в `main` іншою сесією** (PR #139): Morning Brief `cb4b50e8` «блок Стан портфеля», міграція `20261105130633`, `sql/2026-11-05_w5_7_brief_portfolio.sql` | `get_workflow_history` брифінгу; `schema_migrations` |
| 4: застарілі версії core | виправлено у цій гілці: `README.md:25`, `HANDOVER_CTO.md` (2 місця) → `978db8b8`, 193 вузли (`TECH_SPEC:217`, `START_PROMPT_HQ` уже виправлено в `main`) | `grep 40abff53` |
| 6: запит C-3 без `company_id` | виправлено у `CTO_CHECKPOINT_PROMPT.md` | файл |
| 5: tenant-скрипт | у `main` скрипт уже містить `archi_bot_mode_state`, `n8n_chat_histories`; показує **17 вузлів без `company_id`** — знахідку підтверджено, не виправлено | `check_tenant_filter.py` |
| 2 / 2А, 3 / 3А: жовтий у `Build MiniApp Data` і запасні пороги | **Не застосовано до живого n8n.** Підготовлено й перевірено точний патч (нижче). Спробу на вузлі `AN: Attach Block` виконано, побайтово звірено (змінено лише цей вузол, `connections` і `settings` без змін) і **відкочено** `restore_workflow_version` до `978db8b8` (чернетка `229f011a` = активна за вмістом; live не публікувалось). Причина: `update_workflow` приймає лише повний `jsCode`; `Build MiniApp Data` має ~40 КБ — ручне перенесення такого тексту небезпечне. Правильне рішення — W1.8 (кольори й пороги в SQL), а не ручне редагування 40 КБ | `get_workflow_details` до/після |
| 4 / 4А: `company_id` у `session_id` чернеток і в `archi_bot_mode_state` | **Не розпочато.** Потребує дизайну: міграція `archi_bot_mode_state`, зміна 21 інтерпольованого вузла, нових ключів `n8n_chat_histories.session_id` (118 рядків, у т.ч. архівні), 3 вузлів `memoryPostgresChat`; тест на 2 акаунтах неможливий | live SQL 06.11 |
| 7–14 | без змін | — |

### Патч 2А + 3А (перевірений, не застосований)
Вузол `Build MiniApp Data`, чотири зміни; вузол `AN: Attach Block` — перша.
1. `function rule(k, d){ var v = toNum(RULES[k]); return v === null ? d : v; }` → `function rule(k, d){ var v = toNum(RULES[k]); if (v === null) { throw new Error('Поріг відсутній у archi_thresholds: ' + k); } return v; }` (обидва вузли; усі ключі `rule('…')` існують у `archi_thresholds` — перевірено, пропущених 0).
2. `signals.push({c:'yellow', t:'Готовність за оцінкою ПМ не збігається…` → `c:'red'` (мінус «за прогнозом − ПМ» за п. 15).
3. `signals.push({c:'yellow', t:'Оптимістичний прогноз ПМа…` → `c:'green'`; видалити рядок `if (cls.etc === 'green') cls.etc = 'yellow';` (ETC нижчий за план — краще за план, п. 7/15).
4. `var yellows = signals.length - reds;` → `var yellows = signals.filter(function(s){ return s.c==='yellow'; }).length;`
Наслідок: група «Під загрозою» за ETC лишається порожньою (підпис про оптимістичний прогноз застарів — прибрати разом із W1.8).

### Потрібне від власника для завершення
- Дозвіл на W1.8 як спосіб виконання 2А/3А (кольори й пороги в SQL, n8n лише відображає) — рекомендовано; або дозвіл на ручну заміну 40 КБ коду з побайтовою звіркою.
- Для 4А: підтвердити дизайн — `company_id` додається до `archi_bot_mode_state` як NOT NULL (оператор без компанії → службовий нульовий UUID?) і до префікса `session_id`; старі 118 рядків `n8n_chat_histories` — залишити без змін (історія) чи архівувати.

### Оновлення 06.11.2026 (рішення власника «роби як радиш» = варіант А)
- 2А/3А виконуються через W1.8 (кольори й пороги в SQL) — дизайн `docs/W1_8_DESIGN.md`; реалізація не розпочата, живий n8n не змінювався.
- 4А: **виправлення пропозиції** — нульовий UUID для оператора не підходить (`NULL` в `archi_bot_mode_state.company_id` = «компанію не вибрано» у `Resolve Company (Telegram)`); дизайн ключів — `docs/W1_8_DESIGN.md` §5.
