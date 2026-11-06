# ARCHI — дизайн W1.8 (формули, пороги й кольори лише в SQL) і W1.6-ключі сесії
Версія 1 · 06.11.2026 · джерело: аудит `docs/handover/audits/CODE_AUDIT_2026-11-05.md`, рішення власника «2А, 3А» (06.11.2026: «роби як радиш» — варіант А: W1.8 замість ручної заміни 40 КБ коду); `CLAUDE.md` п. 15, 31. Статус: **дизайн; живі системи не змінено.**

## 0. Місце · вплив · борг · масштаб
- Місце: вузол карти W1.8 (борг A-1, D14, `FORMULAS` §7.2), після W1.5 (пороги на клієнта — виконано).
- Зачіпає: вузли `Build MiniApp Data`, `AN: Attach Block`, браузерний код `Build MiniApp HTML` (n8n лише відображає); `archi_report_today`, `archi_thresholds`, `company_thresholds`; Owner View, чат власника.
- Борг, який закриває: запасні пороги в `rule()` (аудит, знах. 2), жовтий поза винятками п. 15 (знах. 3), розрахунки поза SQL.
- Масштаб: функція приймає `company_id`; пороги беруться через `archi_threshold(company, key)`; N клієнтів без змін коду.
- Не перевірив: чи всі показники Owner View мають еквівалент у `FORMULAS`; поведінку Mini App з новим JSON у реальному Telegram.

## 1. Мета від кінця
Owner View показує ті самі числа й кольори, що й зараз (рішення п. 15), але кожен колір і сигнал приходить готовим із SQL. Відсутній ключ порога — явна помилка, а не запасне значення. Критерій приймання: побайтово однаковий результат на 18 проєктах до/після (крім свідомих змін 2А).

## 2. Що рахується не в SQL (інвентар `Build MiniApp Data`, `AN: Attach Block`, 06.11.2026)
| Блок | Зараз | Ціль у SQL |
|---|---|---|
| `cls.rent`, `cls.profit` (відхилення прогноз/план) | n8n, пороги `rent_drop_pp*`, `profit_*_pct` | `archi_project_signals` |
| `cls.etc` | SQL (`etc_gap_signal`) + надбавка «оптимістичний прогноз» в n8n | SQL; надбавку прибрати (2А) |
| `cls.received`, `cls.acts` (неоплата) | n8n, `unpaid_*` | SQL |
| `cls.cpi`, `cls.cpiH` (ефективність виконання) | n8n, `cpi_*` | SQL (назви колонок — за п. 14, окремо) |
| стадії: терміни `slip`, `docCls`, блокер `bCls` | n8n, `slip_red_days`, `doc_prob_*`, `block_red_days` | SQL |
| сигнал «готовність ПМа ≠ годинам» | n8n, жовтий | SQL, **🔴** (2А) |
| «оптимістичний прогноз ПМа» | n8n, жовтий + `cls.etc` | SQL, без кольору відхилення (ETC нижче плану = краще, п. 7/15) |
| `status`, `reds`, `yellows`, групи critical/attention/normal | n8n | SQL (`yellows` = лише сигнали з винятків п. 15) |
| hero-картки: `idxSig`, `ppSig`, `heroCls` | n8n | SQL (поруч із `archi_idx_signal`) |
| АН: `st`, `sig` | `AN: Attach Block` | SQL (`contract_type='visit'`) |

## 3. Цільові об'єкти
1. `archi_project_signals(p_company uuid)` → по проєкту: `status`, `reds`, `yellows`, `cls` (jsonb), `signals` (jsonb масив `{c, t}`), стадійні класи. Читає `archi_report_today`; пороги — `archi_threshold`; **відсутній ключ → `RAISE EXCEPTION`**.
2. `archi_portfolio_cards(p_company uuid)` → hero-картки й групи.
3. n8n: `Build MiniApp Data` лише форматує текст і числа; `rule()` видаляється.
Всі функції `SECURITY INVOKER`, `search_path = public`.

## 4. Порядок (кожен крок із відкатом)
1. SQL-функції 1–2 поряд зі старим кодом (додавання, нічого не вимикається) + файл `sql/` + міграція `apply_migration`.
2. Тест еквівалентності: старий JSON `Build MiniApp Data` проти нового на 18 проєктах (`scripts/replay/`); розбіжності лише ті, що названі в §2 як зміни 2А.
3. n8n: `Build MiniApp Data` читає готове з SQL; публікація за правилами `CLAUDE.md` (ID відкату, побайтова звірка, `publish_workflow`).
4. Видалити запасні пороги й мертву гілку `slip → yellow`; оновити `FORMULAS` §6–§7, `RELEASE_PLAN`, перехідний промпт, експорт `workflows/`.
Кроки 3–4 змінюють живий n8n — окреме «так» власника перед кроком 3 (стоп-тригер).

## 5. W1.6 · ключ режиму й чернеток (рішення «4А» власника, виправлення до дизайну)
**Виправлення моєї пропозиції 06.11.2026:** службовий нульовий UUID для оператора **не підходить**. `Resolve Company (Telegram)` вибирає компанію так: `COALESCE(user_access.company_id, archi_bot_mode_state.company_id, найстарша компанія)`. Для оператора `NULL` у `archi_bot_mode_state.company_id` означає «компанію не вибрано»; ненульовий UUID зламав би цей вибір. Тому `company_id` в `archi_bot_mode_state` лишається допускати `NULL` (як у `03` §4), а:
- для ПМ/власника вузли режиму пишуть `company_id` отриманої компанії;
- ключ чернетки й пам'яті — `<company_id>_<chat>_<режим>_<project_id>`; охоплює 3 вузли `memoryPostgresChat`, 6 вузлів `Reset/Clear Draft`, код `WR: Hard Logic Engine` (12 місць), `WR: Determine Route`, `WR: Build WR Prompt`, `Import: Parse Agent Output`, `Meeting: Parse Agent Output`;
- існуючі 118 рядків `n8n_chat_histories` не змінюються (історія, DEMO); нові ключі діють з моменту публікації.
Інвентар (live JSON 06.11.2026): 15 вузлів Postgres із `archi_bot_mode_state`/`n8n_chat_histories` без `company_id`, 3 вузли пам'яті, 5 code-вузлів із ключами.
Тест: динамічно перевірити ізоляцію можна лише з другим Telegram-акаунтом і другою компанією (T4–T6) — до цього критерій R-2 на рівні n8n не виконується.
