# ARCHI — технічний документ для CTO
Версія 1 · 05.11.2026. Позначки — як у `00_START_HERE.md`. Цей документ — карта. Деталі й джерела істини: `docs/ARCHI_TECH_SPEC_v3_1.md`, `docs/FORMULAS.md`, `docs/W1_DESIGN.md`, `docs/NODE_MAP.md`, `SECURITY.md`. Усе, що розходиться з живою системою, виправляється за живою системою (`CLAUDE.md`, ритуал старту).

## 1. Підсумок для CTO
| Питання | Відповідь |
|---|---|
| Що це | Оркестраційний шар над проєктними даними: план + факт + прогноз → метрики, сигнали, відповіді |
| Де логіка | n8n Cloud: core workflow на 191 вузол, плюс 3 допоміжні workflow. Обчислення — в SQL (Supabase Postgres) і частково в Code-вузлах n8n |
| Де дані | Supabase проєкт `bxawceksdkqlbkdgjvyz`, схема `public` |
| Клієнтські канали | Telegram-бот (чат, звіт, імпорт, брифінг), Telegram Mini App (Owner View, Weekly Render), xlsx |
| LLM | Anthropic `claude-sonnet-4-6` (чат, брифінг), OpenAI `gpt-4o` (звіт, імпорт, зустрічі, фото), OpenAI transcribe (голос) |
| Стан | Прототип на демо-даних; один демо-тенант; безпека — свідомі прийняті ризики (розділ 9) |
| Найбільші технічні питання | Моноліт на 191 вузол в n8n (OD-14); частина формул ще поза SQL (W1.8); безпека (токен, RLS); відсутність автотестів на більшості вузлів; відсутність моніторингу |
| Перша рекомендація | Розділ 12 |

## 2. Архітектура
### 2.1 Шари (цільові й поточні)
```
АДАПТЕРИ (замінні)          DATA TOTAL (Postgres)            ARCHI-ядро                  ЕКРАНИ
Кошторис Sheets (K6sm)  ─┐   project_metrics (план+розрахунок) ┐
Звіт ПМа (Telegram)     ─┤   wr_weekly_snapshots, wr_plan_items│ тригери          Owner View (Mini App)
Години/гроші (бот)      ─┼─► time_log, money_log, payment_*    ├─► archi_recalc() ─► Чат-агент (Claude)
Договір (RC7H)          ─┤   meeting_log, kp_log               │   вʼю archi_*     Weekly Render, xlsx
Знання з чатів (план)   ─┘   companies, user_access, ...       ┘   функції evm_*   Ранковий брифінг, /status
```
Принципи: адаптери замінні, методологія незмінна; обчислення в одному місці; жодних тенант-залежних констант у коді (`TECH_SPEC` §2, `ROADMAP` §3).

### 2.2 Інваріант єдиного обчислення
Кожен показник обчислюється в одному місці й показується всюди з нього.
- Рівень проєкту — `archi_recalc()` (SQL) і SQL-вʼю/функції: `archi_report_today`, `archi_snapshot_history`, `archi_plan_execution`, `archi_weekly_progress`, `archi_*_signal`.
- Колір і поріг рахує лише SQL (`CLAUDE.md` п. 7).
- **Відомі порушення (борг):** частину сигналів і агрегатів портфеля ще рахує код вузла `Build MiniApp Data` в n8n; `AN: Attach Block` має власні `rule()` і кольори; браузер рахує різниці й знаки (`TECH_SPEC` §2.1, D14, `FORMULAS` §7.2). Усунення — вузол карти **W1.8**, власник вирішив зробити це після W1.5 («серце ARCHI — формули — має бути в SQL», п. 31).

### 2.3 Перерахунок
`public.archi_recalc(p_project text DEFAULT NULL)` (+ `archi_recalc_stages()`, `archi_recalc_visit()`). Тригери: `archi_recalc_time` (time_log), `archi_recalc_money` (money_log), `archi_recalc_wr` (wr_weekly_snapshots), `archi_recalc_schedule` (payment_schedule), `archi_recalc_plan` (project_metrics). Workflow `archi_recalc` не викликає.

## 3. Реєстр середовища (без секретів)
| Компонент | Ідентифікатор | Примітка |
|---|---|---|
| n8n | `osbbcopilot.app.n8n.cloud` | хмарний; проєкт власника |
| Core workflow | `CKwCsGIwyw9feCY5` «DEMO Archi Agent» | `activeVersionId` `a4c89c3c-3892-40d0-91e6-7e9ba5eb49d9`, 191 вузол (05.11.2026) |
| Koshtorys Ingest | `K6smBd5xWZLWx9rr` | 16 вузлів, активна `cf904641`; експорт `workflows/Archi_Koshtorys_Ingest_K6sm.json`; спадковий адаптер |
| Document Intake | `RC7HNVlJtuPLtvYV` | 5 вузлів, `d86d127a`; експорт `workflows/Archi_Document_Intake_RC7H.json` |
| Sheets Helper | `nGcSyWfuMO7vjTn6` | ручний, неактивний, 7 вузлів |
| **Morning Brief** | `J3Oqcaa2YBEsVSng` «ARCHI: Morning Brief» | 10 вузлів, опублікований; `activeVersionId` `ae7e4e3b-eaa7-4ff6-b108-c6edec0311f4`; код `workflows/Archi_Morning_Brief.sdk.ts` |
| Не чіпати | `I3K5tBj0FWF1dbWb` (Representative Bot) | чужий проєкт власника |
| Інші workflow в акаунті | 103 workflow усього (live, 05.11.2026): `Task Dispatcher` (активний), `DS Executor`, `Archi Protocol Format Helper` (неактивний, застарілий) і ~90 тимчасових `TEMP:` | **не частина ARCHI**; не змінювати без власника. ARCHI = 5 workflow: core, K6sm, RC7H, Sheets Helper, Morning Brief |
| Supabase | `bxawceksdkqlbkdgjvyz` «matvieiev-bots» | у базі є чужі таблиці (`_bak_*`, `jarvis_*`, `shift_*`, `bot_*`, `archi_bot_semantic_memory`) — не частина ARCHI |
| Telegram-бот | `@archi_demo_bot` | credential n8n `Telegram account 4` |
| Credentials n8n (імена) | `Postgres account`, `Telegram account 4`, `Anthropic account`, OpenAI account(s), Google Drive/Sheets/Docs | значення не в репозиторії |
| Mini App endpoints | `/webhook/demo-archi-owner-view[-data]`, `demo-archi-weekly-render[-data]`, `demo-archi-export` | розділ 6 |
| Демо-компанія | `00000000-0000-4000-8000-000000000001` (`code='DEMO'`, `kind='demo'`) | оператор: telegram id `304884647` |

**Підводні камені середовища (Факт):**
- Автопідстановка credentials при створенні workflow через SDK може вибрати не того Telegram-бота й не підставляє credential у HTTP-вузли. Після створення завжди перевіряти `get_workflow_details`.
- Прямий вихід з cloud-сесії розробки до `*.supabase.co` заблокований проксі; SQL виконується через MCP-інструменти.
- Експорт core JSON у git завжди з заглушкою `<TELEGRAM_BOT_TOKEN>`, перед комітом `grep` токена = 0.

## 4. Модель даних
Повна схема — `TECH_SPEC` §3 і `sql/`. Нижче — карта.

### 4.1 Ядро (Data Total)
| Таблиця / об'єкт | Призначення | Хто пише |
|---|---|---|
| `companies`, `user_access` | клієнти й ролі (`owner`, `pm`, `gap`, `executor`, `operator`); `operator` ⇔ `company_id IS NULL` | міграції, адміністрування |
| `project_metrics` | один рядок на проєкт: план (контракт, години, ETC_план по стадіях, рентабельність) і розрахункові поля (факт, прогноз, `stage_data`, `data_updated_at`); `contract_type` ∈ (`stages`, `visit`) | план — Кошторис/міграції; розрахунок — лише `archi_recalc` |
| `wr_weekly_snapshots` | знімок звіту ПМа за тиждень (унікально `(company_id, project_id, week_start)`): готовність по стадіях, ETC_прогноз по стадіях, дедлайни, ймовірності, блокер, тексти | потік «Фінал» |
| `wr_plan_items` | пункти плану тижня зі статусами `pending/done/not_done/no_answer`, перенесення (`origin_week`, `carry_count`) | потік звіту |
| `archi_wr_inbox` | черга повідомлень ПМа до «Відправити» (RLS увімкнено) | потік звіту |
| `time_log`, `money_log` | години й гроші, `статус='confirmed'` після «Фінал»; `source`, `created_at` | імпорт ботом |
| `payment_schedule` | графік актів і документації: `подія`, `дата_план`, `сума_план`, `ймовірність_план`, `статус_план` | Кошторис, міграції |
| `rates` | ставки по посадах (7 посад, глобально; потрібна відповідність на клієнта, W3.6) | вручну |
| `meeting_log`, `kp_log` | зустрічі; облік КП | бот |
| `archi_thresholds` + `company_thresholds` | 31 порог і параметри методології: значення за замовчуванням + перевизначення по компанії; функції `archi_threshold(company,key)`, `archi_rules(company)` | міграції |
| `archi_bot_mode_state` | стан режиму бота й активної компанії оператора | бот |
| `owner_prefs` | налаштування ранкового брифінгу: `brief_time`, `tz`, `days`, `enabled`, `last_sent_on` (RLS без політик) | вручну / міграція |
| `evm_packages`, `evm_package_done` | гілка «EVM (класичний)»: базовий план пакетів і факт виконання | міграції; RLS без політик |
| `n8n_chat_histories` | пам'ять LLM-агентів (звіт, імпорт, зустріч) | n8n |
| Вʼю | `archi_report_today`, `archi_snapshot_history`, `archi_plan_execution`, `archi_weekly_progress`, `evm_classic_today` | SQL |
| Функції | `archi_recalc*`, `archi_*_signal` (з перевантаженнями `p_company`), `archi_snapshot_evm`, `archi_morning_brief(p_company, p_asof)`, `evm_classic_indices`, `evm_classic_at` | SQL |
| Застаріле | `project_metrics_live` (лінійна оцінка готовності за годинами — суперечить методології; не використовується), `rates_coverage_check` (діагностика), стовпець `wr_weekly_snapshots.final_message` | видалення — рішення власника |

### 4.2 Ключі й тенантність (W1)
- Ключ проєкту — `(company_id, project_id)`; `project_id` — людський код, унікальний у межах клієнта (OD-2).
- `company_id` NOT NULL у таблицях Archi й `evm_*` (live SQL 05.11.2026: 10 з 11 перевірених таблиць; **виняток — `archi_bot_mode_state`, де `company_id` допускає NULL**, бо стан режиму бота веде й оператор без компанії); міграції M0–M6 застосовано 03.11.2026 з відкатами (`sql/2026-11-03_w1_*`).
- Ізоляцію доведено на рівні БД: тест T2/T3 — однаковий код проєкту у трьох компаніях, `ON CONFLICT` не чіпає чужі рядки, вʼю повертають рядки лише своєї компанії, вставка без `company_id` відхиляється (`sql/tests/w1_isolation_T2_T3.sql`).
- **Не доведено:** ізоляцію на рівні n8n (потрібен другий Telegram-акаунт, тести T4–T6); 245 рядків `wr_plan_items` зі старими ID (`ARCH-…`, `ARCH2-…`): дизайн D2 передбачає перенесення в `wr_plan_items_legacy` з відкатом, **але таблиці `wr_plan_items_legacy` у базі ще немає** (live SQL 05.11.2026), тобто крок не виконано; FK для логів не додані (`ROADMAP` W1.1).
- n8n підключається до Postgres прямим з'єднанням, що **обходить RLS**; ізоляцію тримає фільтр `company_id` у запитах. Перевірка наявності фільтра: `scripts/check_tenant_filter.py`.

### 4.3 Демо-дані (п. 18)
Усі наявні дані демо. Набір: 14 договорів стадій (`DEMO-01…10` і 4 «реальні» `22-24`, `24-11`, `24-37`, `24-52`, переведені в демо), 4 договори АН, 8 тижнів знімків. Генерація й відкат — `sql/demo_seed_*`, `sql/*_rollback.sql`.

## 5. Потоки n8n
Детальна карта — `docs/NODE_MAP.md` (генерується `python3 scripts/gen_node_map.py`).

### 5.1 Вхід Telegram (core, `message`)
| Гілка | Що робить |
|---|---|
| Головна | `archi_bot_mode_state` → `WR: Determine Route` → `WR: Hard Logic Engine` → `WR: Route` (18 виходів: меню, вибір проєкту, звіт ПМа, імпорт, зустріч, Кошторис preview/commit, статус, довідник, скидання, черга звіту) або не-WR: `/status`, Weekly Render, Owner View, чат |
| Doc Intake — команда | `договір <id>` |
| Doc Intake — вміст | режим `document_intake` + файл/Drive → RC7H |
| KP Log | `КП: N` |
Тригер приймає лише `message` (групових подій і `edited_message` немає — потрібно для W10). Гілки 2–4 не блокують головну (`Is Parallel Cmd?` глушить чат-гілку; наживо не перевірено).

### 5.2 Звіт ПМа
Повідомлення (текст, голос → `WR: Transcribe`, фото → `WR: Analyze Image`, документ → PDF/TXT) → `buffer_data` → `WR: Inbox Add` (`archi_wr_inbox`) → «📥 Прийнято · у черзі N» (без LLM). «📤 Відправити» або «✅ Фінал» → `WR: Fetch Inbox` → `WR: Build WR Prompt` → `WR: Agent` (gpt-4o, пам'ять 30) → **`WR: Parse Agent Output`** (детермінована перевірка: числа й блокер лише з тексту ПМа, п. 9; підсумки за `FORMULAS` §5; уточнення) → `WR: Inbox Consume`. «Фінал» → один SQL-вираз: UPSERT `wr_weekly_snapshots` + статуси `wr_plan_items`; далі план наступного тижня → тригер → `archi_recalc()` → екрани.
Тести: `tests/wr_parse_agent_output` (29/0).

### 5.3 Чат-агент
`Build MiniApp Data` → `Build Request Body` (детектор Q1–Q10, дані пораховані кодом, глосарій, правила «не вигадувати») → Anthropic `claude-sonnet-4-6` (`max_tokens 2600`, `temperature 0.2`) → `Sanitize Reply` (Markdown → HTML Telegram) → відправка. Пам'яті розмови немає. Тексти Q1–Q10 продубльовано у 4 місцях (`Send Questions Menu`, `Send Reply (Questions)`, `Is Fixed Question?`, `WR: Determine Route`): зміна питання = правка всіх чотирьох.

### 5.4 Owner View, Weekly Render, xlsx
`Validate InitData` → резолвер компанії → `Fetch Project Metrics` (+ `archi_rules` по компанії) → `Build MiniApp Data` → JSON; сторінка — окремий вебхук `Build MiniApp HTML`. Weekly Render: `Fetch All Project Metrics` + `Fetch Weekly Snapshots For Grid` → `Build Weekly Render Data` → `Build Weekly Render HTML`. xlsx: `Xlsx: Build Rows`.
**Борг:** `Fetch All Weekly Snapshots` без `WHERE` і `LIMIT`; навантажувального тесту немає (W4.5).

### 5.5 Кошторис і договір
`кошторис <id>` → K6sm preview (перевірки K1–K11) → «затвердити» → запис плану в `project_metrics` і `payment_schedule`. Гілка `AN:` для вкладок `<id>-АН`. `договір <id>` → RC7H: файл у Google Drive, URL у `contract_file_url`. Усе це спадковий адаптер (Sheets), виводиться з обігу (п. 17).

### 5.6 Ранковий брифінг (W5.7)
```
Every 5 Minutes → Find Due Owners ─┐
Manual Test → Test Recipient ──────┴─► Load Brief → Build LLM Request → Call Anthropic
                                          → Validate And Render → Send Brief → Mark Sent
```
- `Find Due Owners`: `owner_prefs` з `enabled`, `isodow ∈ days`, поточний час у вікні 30 хв від `brief_time`, `last_sent_on` ≠ сьогодні.
- `Load Brief`: `archi_morning_brief(company)` повертає jsonb: `actions[]` (rank, project_id, kind, score, facts, advice), `horizon_7d[]`, `data_updated_at`.
- Правила й вага (score): блокер 100 + дні; `sub_blocked` 120; акт 90 − днів до дати (статус «заплановано», вікно −30…+7 днів); дедлайн документації 75 − днів; дія з наради 65 − днів; ETC перевитрата (`etc_red`) 70 + % від BAC; рентабельність нижче плану 55 + різниця; немає звіту 60 (з четверга); немає прогнозу 50. Не більше 2 дій на проєкт, топ-5.
- `advice` (адресат за роллю, режим, мета) — вираз `CASE` у SQL, не в промпті.
- LLM (`claude-sonnet-4-6`, `temperature 0.2`) формулює `headline`, `why`, `message`; системний промпт — `docs/MORNING_BRIEF_PROMPT.txt`.
- `Validate And Render` (Code): пункт приймається, якщо збігається `rank`, довжини в межах, немає слова «залишок», немає номерів чужих проєктів, **усі числа є серед фактів цієї дії**; інакше підставляється шаблон за метою. Звіт надсилається і при недоступному LLM.
- Перше тестове надсилання: виконання 6953, Telegram `message_id 1774`.

## 6. API й авторизація
| Ендпоінт `/webhook/…` | Призначення | Авторизація |
|---|---|---|
| `demo-archi-owner-view` | HTML Owner View | немає (статична сторінка) |
| `demo-archi-owner-view-data` | JSON | initData Telegram |
| `demo-archi-weekly-render` | HTML | немає |
| `demo-archi-weekly-render-data` | JSON | initData |
| `demo-archi-export` | xlsx | initData |
`initData`: підпис Ed25519 Telegram (публічний ключ Telegram), `auth_date` < 24 год; після цього резолвер компанії читає `user_access` за `telegram_user_id`; немає запису → «доступ не надано». Раніше доступ давав зашитий allowlist у 4 вузлах; з 03.11.2026 замінено резолвером (`Resolve Company (Telegram|Owner View|Weekly Render|Xlsx)`, `Has Access`, `Attach Company`). **Не прогнано в Telegram.**

## 7. Формули і пороги
Єдине джерело — `docs/FORMULAS.md` (ID: D — вхідні, E — ланцюжок EVM-подібних індексів Archi, F — показники проєкту, S — сигнали, P — портфель, V, R, H, PX, K — гілка класичного EVM). Розробнику потрібно прочитати `04_METHODOLOGY_FOR_DEVELOPERS.md`, потім FORMULAS. **Зміна формули, порогу або підпису = оновлення FORMULAS тим самим комітом** (`CLAUDE.md` п. 5).
Пороги: таблиця `archi_thresholds` (значення за замовчуванням) + `company_thresholds` (перевизначення); читання лише через `archi_threshold`/`archi_rules`. Поточні значення відхилень від плану: `etc_*`, `rent_drop_pp*`, `profit_*_pct`, `slip_red_days` = 0; `idx_*` = `cpi_*` = 1 (п. 15).

## 8. Тести й перевірки, що є
| Інструмент | Що перевіряє |
|---|---|
| `scripts/check_docs.py` | узгодженість документації: індекс, лічильники, нумерація (0 помилок на 05.11.2026) |
| `scripts/check_report_form.py` | відповідність форми звіту (0 розбіжностей, 01.11.2026) |
| `scripts/check_tenant_filter.py` | наявність `company_id` у запитах n8n |
| `scripts/replay/` | прогін екранів на живих даних (112 перевірок Weekly Render, 0 розбіжностей, 05.11.2026) |
| `tests/wr_parse_agent_output` | розбір відповіді агента звіту: 29 пройдено, 0 помилок |
| `sql/tests/` | ізоляція T2/T3; перевизначення порогів (`w1_5_threshold_override.sql`, **не запущено**) |
| `docs/CTO_CHECKPOINT_PROMPT.md` | повний аудит коду проти документації; останній 03.11.2026: P0 0 · P1 0 · P2 13 |
| Незалежна звірка F-02/F-13/F-15 | 14/14 збіг (15.10 і 01.11.2026) |
**Немає:** тестів `Build Request Body`, `Build MiniApp Data` (G4); моніторингу помилок; резервних копій за розкладом; відкату автоматизованого (відкат — ручний за `activeVersionId` і `*_rollback.sql`); навантажувального тесту.

## 9. Безпека
Джерело — `SECURITY.md` (12 пунктів). Рішення власника: **не виправляти самостійно**, поки він не скаже.
| Ризик | Стан | Рішення власника |
|---|---|---|
| Токен бота в живому workflow (1 вузол `M: Send Project Picker`) і в історії git | у репозиторії заглушка; чинним лишається лише новий токен | ротація й перенесення в credential — **останній крок розробки перед презентацією першому клієнтові** (п. 25) |
| RLS вимкнений на більшості таблиць Archi (live 05.11.2026: `project_metrics` і `wr_weekly_snapshots` — вимкнений; `companies`, `user_access`, `company_thresholds`, `owner_prefs`, `archi_wr_inbox`, `evm_packages` — увімкнений, у частини без політик); публічний ключ Supabase дає повний доступ до таблиць без RLS | відкрито | повернутись при першому платному клієнті (п. 28, OD-4); R-2 і R-11 до цього не виконуються |
| Mini App HTML-вебхуки без авторизації | сторінка статична, дані за initData | прийнято |
| Weekly Render Data Webhook без авторизації (`SECURITY.md` п. 2) | **виправлено 13.09.2026**, підтверджено виконаннями 5512 (без initData — відмова) і 5513 (з initData — дані) | закрито |
| Бот відкритий для будь-якого користувача Telegram (`SECURITY.md` п. 7) | резолвер `user_access` реалізовано 03.11.2026 (W1.2); у Telegram не прогнано; у `SECURITY.md` статус лишається «не виправлено» до перевірки | рішення D5, п. 30 |
| Google Sheets `anyone writer` на файлі Кошториса | виводиться з обігу | W2.7 |
| Нові таблиці/вʼю без RLS | `owner_prefs`, `evm_*` — RLS без політик; інші — без RLS | кожен новий об'єкт — з RLS за можливості (R-11) |
| Репозиторій | приватний (власник підтвердив) | п. 25, дію в GitHub виконує власник |
Інші пункти `SECURITY.md` (п. 3 credentials Sheets і Postgres, п. 4 Anthropic API, п. 6 і 7б–12 нові таблиці, вʼю й функції без RLS або з RLS без політик) — у файлі `SECURITY.md`; кожен новий об'єкт БД дописується туди тим самим комітом.
Правило: **CTO не вмикає RLS і не ротує токен без власника.**

## 10. Відомий технічний борг
Повний реєстр — `TECH_SPEC` §11 (D1…D14), `CTO_CHECKPOINT_01.11.2026.md` (№1…№12), `CTO_CHECKPOINT_03.11.2026.md`, `DOC_AUDIT_29.10.2026.md`.
| № | Борг | Вузол карти |
|---|---|---|
| T-1 | Формули/пороги/кольори частково в n8n і браузері, не в SQL | W1.8 |
| T-2 | Моноліт 191 вузол; код у JSON, а не у файлах | W8.1, W8.2 |
| T-3 | DDL (`CREATE TABLE IF NOT EXISTS`) виконується на кожне повідомлення (`WR: Ensure Mode Table`, `WR: Ensure Plan Table`) | W1.6 |
| T-4 | 21 Postgres-вузол інтерполює `'{{ … }}'` (лише `chat.id` і регулярно перевірений `project_id`); за кодом ризик низький, параметризація не планується (рішення `RELEASE_PLAN` §117, варіант A) | W1.6 |
| T-5 | `WR: Schedule Reminder (Fri 10:00)` без вихідних з'єднань: нагадування не надсилається (D1) | W5.3 |
| T-6 | Гілка Doc Intake читає `$('WR: Read Mode')` з іншої гілки (клас D2) | CTO 01.11 №8 |
| T-7 | Код і тексти Q1–Q10 дубльовані в 4 вузлах | W8 |
| T-8 | Немає автотестів на більшості Code-вузлів, немає моніторингу, резервних копій, навантажувального тесту | W4.6, W8.4, W4.5 |
| T-9 | `wr_weekly_snapshots.final_message` порожній у знімках потоку черги (WD.1); недетермінізм `WR: Agent` (WD.2) | WD |
| T-10 | Дві суми «бюджет приросту» в Owner View (59 976 грн різниці через проєкт без годин, WD.4–WD.5) | W4.2 |
| T-11 | Колонки з історичними назвами `ev_classic_evm`, `cpi_classic_evm` (це методологія Archi, не класичний EVM) — перейменувати разом із вкладкою EVM | W7.5 |
| T-12 | Застарілі сутності в БД: `project_metrics_live`, `final_message`, колонки `efficiency_contract`, `earned_value`, `paid_volume`, `comparison` | рішення власника |

## 11. Правила змін (процес, обов'язкові)
Джерело — `CLAUDE.md`. Їх треба відтворити в процесі IT-компанії, інакше документація розійдеться з системою.
1. Спершу читати `CLAUDE.md`, `ROADMAP_TO_RELEASE.md`, `RELEASE_PLAN.md` (з кінця), потім міняти.
2. Перед пропозицією змін n8n/Supabase/структури: місце в плані; що з підключеного зачіпає; чи не створює боргу; чи масштабується на N клієнтів; що не перевірено.
3. **n8n:** записати `activeVersionId` до зміни → змінювати через `update_workflow` → отримати workflow й **побайтово** порівняти з надісланим → лише тоді `publish_workflow`. Імпорт JSON — лише для нових workflow. `test_workflow` не запускати без пінування (виконує неспіновані вузли по-справжньому). Після публікації перевірити `grep` видалених/перейменованих змінних у відредагованих Code-вузлах.
4. **Supabase:** схема змінюється лише міграцією (`apply_migration`) з файлом у `sql/` і файлом відкату тим самим комітом. RLS і ротація токена — лише за рішенням власника.
5. Після кожної публікації: переекспортувати JSON в `workflows/` (з заглушкою токена), `python3 scripts/gen_node_map.py`, розділ у `docs/RELEASE_PLAN.md` (що зроблено → результат → спосіб перевірки → checkpoint), оновити `TECH_SPEC`, `FORMULAS`, `SECURITY.md`, `README.md`, «Живий стан» у `TRANSITION_PROMPT`.
6. Перед комітом: `python3 scripts/check_docs.py` = 0 помилок. Новий `docs/*.md` вносити в `docs/README.md`; нове закрите рішення власника — в `docs/DECISIONS_REGISTER.md`.
7. Звірка цифр: незалежний SQL по всіх рядках і полях, а не вибірково; число має джерело: «live SQL», «макет» або «розрахунок вручну». Макет не видавати за живі дані.
8. Номер розділу `RELEASE_PLAN` звіряти з `origin/main` перед комітом (дві паралельні сесії 05.11.2026 зайняли §173).
9. Робочу гілку кінець сесії зливати в `main` (PR + merge).

## 12. Рекомендації CTO [Рекомендація, не рішення власника]
Рішення за власником. Нижче — порядок, у якому зручно приймати систему.
**Перші 2 тижні (прийняття):**
1. Отримати доступи (чек-лист `00_START_HERE.md` §6); пройти `OWNER_MORNING_TEST`; запустити всі скрипти перевірки з розділу 8.
2. Скласти власну карту вузлів core і порівняти з `NODE_MAP.md` (відкат — за `activeVersionId` у `RELEASE_PLAN`).
3. Прогнати резолвер ролей у Telegram (тести T4–T6) із другим тестовим акаунтом: це закриває R-2 на рівні n8n.
4. Запустити `sql/tests/w1_5_threshold_override.sql` у SQL Editor.
5. Перевірити автозапуск ранкового брифінгу 08:30 за київським часом (`executions` workflow `J3Oqcaa2YBEsVSng`, `owner_prefs.last_sent_on`).
**Далі за залежностями карти:** W1.8 (формули в SQL) → W1.2/W1.4 завершення → W2 (модуль плану в ARCHI) → W3.10 (імпорт XLSX/CSV) → W4.5/W8 (інженерія, продуктивність) → W6.1/W6.4 (drill-down, вкладка EVM) → W10 (знання проєкту) → W11. Порядок обґрунтовано: усе, що зберігає дані клієнтів, залежить від W1.
**Рішення OD-14 (n8n чи власний бекенд).** Рекомендація: не вирішувати до завершення W1–W3. Критерії для рішення (G5): кількість клієнтів, вартість підтримки, ролі й RLS, навантаження, тестованість, прив'язка до вендора. Аргументи за міграцію, відомі з коду: 191 вузол у одному workflow, код у JSON, DDL на кожне повідомлення, обмежена тестованість. Аргументи проти: працююча бізнес-логіка зашита у вузлах, а SQL-ядро (`archi_*`, `evm_*`) переносимо без змін. [Припущення] SQL-ядро — найцінніша переносима частина.
**Що переносимо найпершим:** `archi_recalc*`, вʼю й функції — вони вже в Postgres і не залежать від n8n.
