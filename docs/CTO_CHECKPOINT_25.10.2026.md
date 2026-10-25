# CTO Checkpoint — 25.10.2026

Живий `activeVersionId`: `cc94785c-b323-4742-ac97-7aefbdcb2c6e` (179 вузлів, `updatedAt` 2026-10-25T20:02:02Z) | Репо: `versionId cc94785c…` (179) | **Збіг: так** (0 відмінностей у `parameters` 179 вузлів, `connections` ідентичні).
Підсумок: **P0 0 · P1 1 · P2 8** · Підтверджено інваріантів 3/5 (A-1 ✗ — відомий, A-2 ✓, A-3 ✓, A-4 ✓ — лише відомий D1, A-5 ⚠️ — працює, але крихко).
Режим: лише читання (n8n `get_workflow_details`; Supabase `SELECT`). Код і дані не змінювались; змінено лише документи (цей файл, рядок у `RELEASE_PLAN.md`).
Попередній checkpoint: `CTO_CHECKPOINT_22.10.2026.md` (173 вузли, `868f0316`). Різниця +6 вузлів = черга звіту (`WR: Inbox Add`, `WR: Send Inbox Ack`, `WR: Fetch Inbox`, `WR: Inbox Consume`, `WR: Final Has Data?`, `WR: Send Final No Data`, RELEASE_PLAN §93–§97).

**Обсяг (чесно):** виконано повністю — крок 0, A-1…A-5, F-check (структура `archi_recalc_stages`), C-3, C-4, R-form, глосарій (grep), безпека, документація. **Не виконано повністю** (див. «Не вдалося перевірити»): S/P/V-check рядок за рядком, таблиця «показник × контур», верстка 5 вузлів `Send …`.

## Знахідки

| # | Пріор. | Тип | Де | Еталон | Факт (доказ) | Рекомендація | Рішення від |
|---|---|---|---|---|---|---|---|
| 1 | P1 | ARCH | `Build MiniApp Data` (33 `rule(`), `AN: Attach Block` (7 `rule(`, `RULES`, `rent_drop`), SQL | `TECH_SPEC` §2.1 (A-1) | **Факт (grep по 179 вузлах):** пороги/кольори обчислюються у двох JS-вузлах; `AN: Attach Block` дублює пороги `rent_drop_pp*`, `cpi_*`, `unpaid_*`. Не виправлено з checkpoint 22.10 (#5). Значення збігаються (`rule(k, d)`, d = БД) | Окрема ітерація: блок «Авторський нагляд» читати з SQL-сигналів | власник |
| 2 | P2 | DOC | `README.md` рядки 21–22, `ARCHI_TECH_SPEC_v3_0.md` рядок 4 | `CLAUDE.md` «Після зміни в n8n» | **Факт:** історія версій у текстових мітках зіпсована механічною заміною ID: мітка `cc94785c` = «перевірка чисел… варіант Б», далі йдуть описи старіших версій («без дат для завершених стадій, §99» тощо); у `README.md` лишився рядок «172 ноди» (живий 179) | Переписати блок «версії» в обох файлах: одна мітка на ID | виконавець (за згодою власника) |
| 3 | P2 | DOC | `TECH_SPEC` §11 D7 | `TECH_SPEC` §11 | **Факт:** D7 «`WR: Fetch Money Log Acts` без фільтра `статус='confirmed'`» — у запиті вузла є `AND статус = 'confirmed'` → дефект виправлено, документ застарів | Позначити D7 «Виправлено» (з посиланням на розділ RELEASE_PLAN, де виправлено — **Потребує перевірки**, у якому саме) | виконавець |
| 4 | P2 | SEC/DOC | `SECURITY.md` п.1, `workflows/…json` | `SECURITY.md` п.1 | **Факт:** `SECURITY.md` описує токен у трьох вузлах (`Validate InitData`, `WR-Render: Validate InitData`, `M: Send Project Picker`) і цитує токен із закінченням `AAGvc…`. Живий стан: токен-літерал лише в `M: Send Project Picker` (URL `…/bot<id>:AAEdE…/sendMessage`); три `Validate InitData` (включно з `Xlsx: …`) використовують `BOT_ID` + публічний ключ, токена не містять. Закінчення токена в документі й у вузлі різні. Токен лежить у публічному репозиторії двічі (`workflows/…json`, вузол і копія в `activeVersion`) і в `SECURITY.md`. Стан безпеки не гірший, ніж 22.10 (#16) | **Потребує перевірки:** який із двох токенів чинний; оновити `SECURITY.md` до фактичного стану. Не ротувати без рішення власника (`CLAUDE.md` «Заборонено») | власник |
| 5 | P2 | ARCH | `Doc Intake: Is Contract Content?`, `Doc Intake: Extract File Id`, `Doc Intake: Extract Drive Link` | `TECH_SPEC` §11 D2 (клас дефекту) | **Факт (граф):** гілка Doc Intake читає `$('WR: Read Mode')` із сестринської гілки `Telegram Trigger`. Працює, бо `WR: Ensure Mode Table` (y=1040) стоїть вище за Doc Intake (y=1600/1800) при `executionOrder v1`; порядок залежить від координат на полотні | Додати `WR: Read Mode` у ланцюжок Doc Intake або зафіксувати правило «не рухати вузли по Y» у `TECH_SPEC` | власник |
| 6 | P2 | DATA | `archi_thresholds` | `FORMULAS` §6, `TECH_SPEC` A-2 | **Факт (SQL + grep):** ключі, яких не читає ні код, ні SQL-функції: `demo_asof`, `plan_fx_uah_usd`, `profit_yellow_share`. `wr_ready_gap_pp` читає SQL `archi_ready_gap_signal` (OK). Значення БД = резервні значення коду для всіх ключів, що читаються | Видалити або задокументувати 3 ключі (`demo_asof` — код прибрано 18.10, §71) | власник |
| 7 | P2 | DATA | `wr_weekly_snapshots` | C-4 | **Факт (SQL):** 12 із 13 проєктів мають останній звіт 12.10 (13 днів); DEMO-08 — 21.09 (34 дні). DEMO-03 — 19.10 (6 днів; знімок id 217 — тестовий, 25.10.2026). Сигнала «застарілий звіт» немає (D8) | Лишається ризик D8 | власник |
| 8 | P2 | DATA | `project_metrics.actual_cost` DEMO-02 | C-3 | **Факт (SQL C-3):** `ac_indep = 183004`, `ac_db = 183005` (різниця 1 грн, округлення); `cf_indep = cf_db` у всіх 14 проєктів із прогнозом; 24-37 і DEMO-02 без прогнозу (немає ETC по 4 стадіях) — як і 22.10 (#14) | Нічого не робити (округлення) або вирівняти `round` | — |
| 9 | P2 | ARCH | `WR: Schedule Reminder (Fri 10:00)` | `TECH_SPEC` §11 D1 | **Факт:** єдиний тригер без вихідних, тип `cron` (22.10 #15). Решта «ізольованих» вузлів — sub-nodes LangChain (`lmChat…`, `memoryPostgresChat`) з'єднані типом `ai_*`, не знахідка | Рішення власника: підключити або видалити | власник |

## Перевірено й відповідає (коротко, з доказом)

- **Збіг репо і живого n8n.** `versionId = activeVersionId = cc94785c…` в обох; 179 вузлів; імена вузлів ідентичні; `parameters` кожного вузла й `connections` збігаються (Python: 0 відмінностей).
- **A-2.** Усі 29 ключів `archi_thresholds` звірено з `rule('<key>', d)`: d = значення БД для кожного читаного ключа (block_red_days 14, cpi 0,85/0,95, doc_prob 3/6, etc 0,05/0,10, idx 0,9/0,7, opt_etc_drop 0,40, opt_ready_max 50, plan_exec 50/70, profit 5/10, rent_drop 5/10, slip_red_days 14, unpaid 0,10/0,25, plan_year_* ), `readiness_gap_pp` 20 — у `WR: Parse Agent Output` і `WR: Fetch Project Metrics Static`.
- **A-3.** `information_schema.triggers`: `archi_recalc_money`, `_schedule`, `_plan`, `_time`, `_wr` — по INSERT/UPDATE/DELETE (5 тригерів).
- **F-check (структура `archi_recalc_stages`).** Фільтр `статус='confirmed'` у `time_log` і `money_log`; `ETC_Total` і `pct_complete` лише при 4 стадіях (`etc_n = 4`, `count(rd_f) = 4`); стадія з планом 0 → готовність 100, ETC 0; підстановки плану замість прогнозу немає (`COALESCE(sn.et…, CASE … THEN 0 END)`); `EV_контракт = contract × pct_complete`, `EV_classic = bac × pct_complete`, `cpi_classic_evm = ev_classic / actual_cost` (див. `CLAUDE.md` п. 8). **Не звірено** рядок за рядком F-01…F-20 з таблицею `FORMULAS`.
- **C-3.** `ac_indep` = `ac_db` і `cf_indep` = `cf_db` у всіх проєктах, крім округлення на 1 грн (#8).
- **R-form.** `python3 scripts/check_report_form.py` → «Розбіжностей: 0».
- **Тексти (CLAUDE.md п.1).** «Залишок» у вузлах — лише в забороняючих інструкціях промптів (`Build Request Body` ×2, `WR: Build WR Prompt` ×2). У колонках БД слова «залишок_прогноз…» не рахувались як текст для людини.
- **Безпека (стан відносно `SECURITY.md`).** Токен-літерал: 1 вузол (було 3 у документі); allowlist `304884647`: `Validate InitData`, `WR: Hard Logic Engine`, `WR-Render: Validate InitData`, `Xlsx: Validate InitData`. RLS: **вимкнено** на 28 таблицях ARCHI (бекапи `_bak_*`, `project_metrics`, `time_log`, `money_log`, `wr_weekly_snapshots`, `wr_plan_items`, `kp_log`, `meeting_log` та ін.); **увімкнено** на `archi_thresholds`, `archi_wr_inbox`, `payment_schedule`, `monthly_goals` і частині `_bak_*` — без змін відносно `SECURITY.md` (рішення власника). SQL з інтерполяцією `'{{ … }}'` — 22 вузли (без змін).
- **Маршрутизація (за живими прогонами власника 25.10.2026, не за повним трасуванням коду).** «🆕 Новий», «📤 Відправити», «✅ Фінал» у режимі звіту пройшли live (RELEASE_PLAN §98–§111). Кнопки «📄 Чернетка» і «❌ Скасувати» цього дня не натискались.
- **Попередні знахідки 22.10, що закриті:** #1, #2, #3, #4, #9 (рішення §86); #10 (репо = живий, цього разу збіг).

## Не вдалося перевірити (чому)

- **S-check / P-check / V-check рядок за рядком** (`Build MiniApp Data`, 33 КБ коду): перевірено лише, що всі пороги й резервні значення збігаються з БД і `FORMULAS` §3 (S-02…S-15), а не умови кожної клітинки. Потребує окремої сесії.
- **Таблиця «показник × контур»** (крок 3): не складалась; перевірено лише, що Weekly Render без грошових сум не змінювався з 22.10.
- **Верстка 5 вузлів `Send …`** і брифу `WR: Send Project Confirmation` (крок 4): не перечитувались.
- **Чинність токена** (#4): без виклику Telegram API; **Потребує перевірки**.
- **Owner View `D2`** (чи бачить Owner View КП після виправлення §48): не виконувалось.

## Зміни відносно попереднього checkpoint (22.10.2026)

- Додано: черга звіту (`archi_wr_inbox`, 6 вузлів), перевірка чисел і дат ПМа в `WR: Parse Agent Output` (§104–§111), нормалізація плану й `wr_gap` у SQL (§109–§110), `CLAUDE.md` п. 9.
- Закрито: знахідки 22.10 #1–#4, #9, #10, #13.
- Без змін: #5 (A-1) → тут #1; #15 (cron) → #9; #16 (токен) → #4 (+ невідповідність `SECURITY.md`); #14 (24-37, DEMO-02) → #8.
- Нове: #2, #3, #5, #6 (три ключі), #7 як актуальний стан.
