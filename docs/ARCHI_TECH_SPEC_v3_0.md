# ARCHI — ТЕХНІЧНА СПЕЦИФІКАЦІЯ v3.0

**Дата:** 15.10.2026 · **Замінює:** `ARCHI_TECH_SPEC_v2_0.md` (v2.2 від 04.10.2026 — історичний документ)
**Звірено з:** n8n `CKwCsGIwyw9feCY5` `activeVersionId 6f702771-f338-4b12-a698-3a6f483238db` (далі — `8bce8982` D2+D4, RELEASE_PLAN §48; далі `9de75532` D10, §49)
(171 нода після §51), Supabase `bxawceksdkqlbkdgjvyz` (схема, тригери, `archi_recalc()`, `archi_thresholds`).
**Супутні документи:** `CLAUDE.md` (закриті рішення), `docs/FORMULAS.md` (усі формули —
ця специфікація їх не дублює, лише посилається на ID), `docs/WEEKLY_REPORT_FORM.md`,
`docs/LAYOUT_STANDARD.md`, `SECURITY.md`, `docs/ARCHI_Obraz_Idealnoho_Rezultatu.md` (методологія «навіщо»).
**Контроль відповідності:** `docs/CTO_CHECKPOINT_PROMPT.md`.

Позначки: **Факт** — перевірено кодом/SQL; **[Припущення]**; **Потребує перевірки**.

---

## 1. Продукт і межі обіцянки

ARCHI — оркестраційний шар над проєктними даними архітектурного бюро: план
(Кошторис) + факт (журнали годин і грошей) + прогноз (щотижневий звіт ПМа) →
метрики, сигнали й відповіді власнику. Три фічі: **Owner View** (Telegram Mini App),
**Archi Consult** (чат-агент, Q1–Q10 + довільні питання), **Щотижневий ритм**
(звіт ПМа → Weekly Render → xlsx).

Тарифи: Light $500/міс (до 8 проєктів), Full $1 000/міс (до 20 проєктів).
Full = продукт + операційна підтримка якості даних (FDO). **[Припущення]**
трудомісткість FDO не виміряна — до пілоту вести облік годин FDO на клієнта.

### 1.1 Що продукт чесно може обіцяти зараз (зовнішній аудит 15.10.2026, прийнято)
- Регулярна видимість портфеля: план / факт / прогноз рентабельності, прибутку,
  годин; сигнали відхилень; перехід від сигналу до причини (дані ПМа + сигнали).
- **Не обіцяти:** управління ліквідністю / касовий розрив / «гроші на зарплату»
  (немає залишків на рахунках і зарплатного фонду — Q4, Q5 відповідають «даних
  немає»); «автоматичний захист прибутку»; багатоклієнтський SaaS (див. §10).
- Прогноз = якість звіту ПМа. Без свіжого звіту прогнозу немає (S-01), і це має
  бути видно власнику (§8).

---

## 2. Архітектура

```
АДАПТЕРИ (замінні)            DATA TOTAL (Postgres, Supabase)          ARCHI (n8n)                 ЕКРАНИ
Кошторис (Sheets) ─K6sm──►   project_metrics (план)          ┐
Звіт ПМа (Telegram) ─────►   wr_weekly_snapshots, wr_plan_items │ тригери        Build MiniApp Data ──► Owner View
Імпорт годин/грошей ─────►   time_log, money_log (транзит)   ├─► archi_recalc() ─► (сигнали, кольори, ──► Чат (Claude)
Графік оплат ────────────►   payment_schedule                │   → project_metrics   портфель)
Договір (файл/Drive) ─RC7H►  project_metrics.contract_file_url │                    Build Weekly Render ─► Weekly Render
КП (команда) ────────────►   kp_log (транзит)                ┘                    Xlsx: Build Rows ───► xlsx
                             archi_thresholds (пороги + план бюро), rates           Build Status Text ──► /status
```

### 2.1 Правило єдиного обчислення (інваріант)
Кожен показник обчислюється **в одному місці** і показується всюди з нього:
- рівень проєкту — лише `archi_recalc()` (SQL);
- сигнали, кольори, агрегати портфеля — лише `Build MiniApp Data` (n8n), спільний для
  Owner View і чату (`Is Chat Request?` розгалужує);
- решта контурів (HTML, чат-промпт, /status, Weekly Render, xlsx) — **тільки
  відображення**. Відомий виняток — колір стадійного блоку в браузері
  (FORMULAS §7.2), підлягає перенесенню.
- Weekly Render і /status кольорів не рахують (Факт: порогів не читають) — нейтральний
  показ план → прогноз.

### 2.2 Перерахунок
SQL-функція `public.archi_recalc(p_project text DEFAULT NULL)` + `archi_recalc_trg()`;
тригери `archi_recalc_time` (time_log), `archi_recalc_money` (money_log),
`archi_recalc_wr` (wr_weekly_snapshots), `archi_recalc_schedule` (payment_schedule) —
INSERT/UPDATE/DELETE; `archi_recalc_plan` (project_metrics INSERT/UPDATE). Workflow
`archi_recalc` не викликає. Формули — FORMULAS §2.

---

## 3. Data Total — схема (Факт, 15.10.2026)

**`project_metrics`** (43 колонки, 14 рядків: DEMO-01…10 + реальні `22-24`, `24-11`,
`24-37`, `24-52`): план — `contract_amount, profitability_plan_pct, profit_plan,
cost_plan_team, cost_plan_subcontract, planned_hours, etc_plan_by_stage,
planned_hours_by_stage, real_rate_team_hour, bac, koshtorys_spreadsheet_id/_sheet,
baseline_at/_by, contract_file_url`; факт і прогноз (пише лише `archi_recalc`) —
`actual_hours, hours_remaining, percent_execution, actual_cost, acts_amount,
money_received, earned_value_contract, ev_classic_evm, cpi_classic_evm, stage_data,
etc_forecast_total_hours, money_to_completion_team/_subcontract, cost_final_forecast,
profit_forecast, profitability_forecast_pct, forecast_confirmed_pct/_week,
nearest_act_date/_probability, nearest_doc_deadline, doc_issuance_probability, updated_at`;
застарілі/невикористовувані — `efficiency_contract, earned_value, paid_volume, comparison`
**Потребує перевірки** (не пише `archi_recalc`).

**`wr_weekly_snapshots`** (19 колонок): `project_id, week_start` (унікальна пара, UPSERT),
`готовність_pct` jsonb, `залишок_прогноз_по_стадіях` jsonb (= ETC_прогноз по стадіях;
назва колонки історична, у текстах — лише ETC), `дедлайн_прогноз_по_стадіях`,
`ймовірність_акту`, `ймовірність_документації`, `блокер` jsonb {types, since, need},
`розбіжність_готовності` jsonb, `plans_next_week, problems, help_needed, pm_comment,
final_message, item_statuses, session_id, created_at`.

**Інші:** `wr_plan_items` (план тижня, статуси пунктів), `archi_bot_mode_state`
(session_id, mode, project_id, context, updated_at), `archi_thresholds` (key, value
numeric, note — FORMULAS §6), `payment_schedule` (RLS увімкнено), `rates`,
`time_log`, `money_log` (статус `confirmed` — **механізм підтвердження: імпорт через бот
пише одразу `confirmed` [Припущення], перевірити**), `meeting_log`, `kp_log`,
`n8n_chat_histories` (пам'ять WR/Import/Meeting агентів).

**Чужі таблиці в тій самій базі** (`_bak_2026092*`, `jarvis_*`, `shift_*`, `bot_*`,
`archi_bot_semantic_memory` тощо) — не частина ARCHI, не чіпати.

---

## 4. Workflow `CKwCsGIwyw9feCY5` — потоки

Детальна карта вузлів — `docs/TRANSITION_PROMPT_2026-10-15.md` §5.

### 4.1 Telegram (`message`) → 4 паралельні гілки
1. **Головна:** режим (`archi_bot_mode_state`) → `WR: Determine Route` →
   WR-потоки (`WR: Hard Logic Engine` → `WR: Route`, 17 виходів: меню, вибір проєкту,
   звіт ПМа, імпорт, зустріч, Кошторис preview/commit, статус, довідник, скидання)
   **або** не-WR: `/status`, Weekly Render, Owner View кнопка, інакше чат.
2. **Doc Intake — команда** `договір <id>`.
3. **Doc Intake — вміст** (режим `document_intake` + файл/Drive-посилання) → RC7H.
4. **KP Log** `КП: N`.
**Ризик (Потребує перевірки):** гілки 2–4 не блокують гілку 1 → можливі подвійні
відповіді (чат-LLM теж відповідає).

### 4.2 Звіт ПМа (канон — `CLAUDE.md` п.2, форма — `WEEKLY_REPORT_FORM.md`)
Кнопка проєкту → бриф (стадії договору, ймовірність документації, план минулого тижня,
проблеми, допомога, план, блокер; «відповіді нема» дозволено) → довільні відповіді
(текст/голос/фото/PDF/TXT) → «📤 Відправити» → `WR: Agent` (gpt-4o, пам'ять 30) структурує →
`WR: Parse Agent Output` детерміновано рахує підсумки (FORMULAS §5), ставить уточнення →
«✅ Фінал» (гейт) → `wr_weekly_snapshots` UPSERT + `wr_plan_items` → тригер →
`archi_recalc()` → усі екрани.

### 4.3 Чат-агент
`Build MiniApp Data` → `Build Request Body` (детектор Q1–Q10; дані пораховані кодом;
глосарій; правила «не вигадувати») → Anthropic `claude-sonnet-4-6`, `max_tokens 2600`,
`temperature 0.2` → `Sanitize Reply` (Markdown → HTML Telegram) → `Is Fixed Question?` →
`Send Reply (Questions)` (клавіатура питань лишається) або `Send Reply` (головне меню).
Пам'яті розмови немає (кожне питання окремо).

**Кнопки фіксованих питань Q1–Q10 (RELEASE_PLAN §51, 15.10.2026).** У головній клавіатурі —
кнопка «❓ Питання» (поряд з «📖 Довідник»). Маршрут: `Is Weekly Render Request?` (false) →
`Is Questions Menu?` (текст починається з «❓») → `Send Questions Menu` (клавіатура з 10 питань +
«Назад»); інакше → `Is Owner View Request?` як раніше. Натиснуте питання — звичайне текстове
повідомлення; детектор `detectIntent` не змінювався. `WR: Determine Route` не віддає тексти Q1–Q10
і «❓ Питання» у сесію тижневого звіту (`isFixedQuestion`). Тексти питань — LOCKED-список
(`OWNER_MORNING_TEST`), Q8 на кнопці: «Чи є небезпечні дедлайни?» (рішення власника 15.10.2026).
У коді тексти продубльовано в 4 місцях (`Send Questions Menu`, `Send Reply (Questions)`,
`Is Fixed Question?`, `WR: Determine Route`) — зміна формулювання питання = правка всіх чотирьох.

### 4.4 Owner View
`Validate InitData` → `Fetch Project Metrics (MiniApp)` + `Fetch KP Log Sum (MiniApp)` →
`Build MiniApp Data` → JSON → `Build MiniApp HTML` (сторінка окремим вебхуком).
Структура екрана (з 15.10.2026, RELEASE_PLAN §54): портфель (таблиця FORMULAS §4 з рядками КП під «Проєкти») →
загальний статус (клікабельні лічильники → перелік проєктів) → синя панель «Показник» (вкладки, плитки, розподіл за показником) → увага →
картка (сигнали → РЕНТАБЕЛЬНІСТЬ → ⛔ → Контракт → Роботи/акти/гроші → Прибуток →
Звіт ПМа → До завершення → CPI).

### 4.5 Weekly Render і xlsx
Без грошових сум (методологія). Колонки — тижні знімків + «Сьогодні (Data Total)»:
рентабельність, ETC, «Години до кінця / бюджет» (F-22, **не готовність**), готовність
стадій ЕП/П/Р, акт, документація, CPI, тексти ПМа. Вигляд не змінювати (`CLAUDE.md` п.3).

### 4.6 Кошторис і договір
`кошторис <id>` → K6sm preview (перевірки K1–K11) → `затвердити` → commit плану в
`project_metrics` + `payment_schedule`. Доступ — `ALLOWED` у `WR: Hard Logic Engine`.
Реальні проєкти бюро мають інший формат вкладок — внесені SQL-ом (RELEASE_PLAN §35).
`договір <id>` → RC7H: файл у Google Drive, URL у `contract_file_url`.

---

## 5. API і авторизація

| Ендпоінт (`/webhook/…`) | Призначення | Авторизація |
|---|---|---|
| `demo-archi-owner-view` | HTML Owner View | немає (статична сторінка, дані — окремо) |
| `demo-archi-owner-view-data` | JSON Owner View | initData |
| `demo-archi-weekly-render` | HTML рендеру | немає |
| `demo-archi-weekly-render-data` | JSON рендеру | initData |
| `demo-archi-export` | xlsx | initData |

**initData (Факт):** Ed25519-підпис Telegram (`signature`, публічний ключ Telegram,
`BOT_ID 8813476306`) + `auth_date` < 24 год (обов'язковий) + allowlist `['304884647']`.
**Чат і WR-бот — без allowlist** (`SECURITY.md` п.7, рішення власника).

---

## 6. Реєстр середовища

| Компонент | ID |
|---|---|
| n8n | `osbbcopilot.app.n8n.cloud` |
| Core workflow | `CKwCsGIwyw9feCY5`, `f9290fa9-ded4-42a4-b70e-d8f9d9140ac3` |
| Koshtorys Ingest | `K6smBd5xWZLWx9rr` (JSON не в репо) |
| Document Intake | `RC7HNVlJtuPLtvYV` (JSON не в репо) |
| Не чіпати | `I3K5tBj0FWF1dbWb` (Representative Bot) |
| Supabase | `bxawceksdkqlbkdgjvyz` |
| Кошторис DEMO | `1Ok4_U9u8kLZ0GJarPbEk4nQsqKeqdLzNNBONNNDgF7g` |
| Бот | `@archi_demo_bot`; власник `304884647` |
| Моделі | Claude `claude-sonnet-4-6` (чат); OpenAI `gpt-4o` (WR/Import/Meeting, фото), OpenAI transcribe (голос) |

---

## 7. Глосарій (канон)

Контракт · ETC_план · Фактичний_час · ETC_факт · ETC_прогноз · Прибуток_план ·
Прибуток_прогноз · Рентабельність_план · Рентабельність_прогноз · Виконано · Акти ·
Оплачено · CPI · ⛔ блокер · ⚖️ розбіжність готовності. «Залишок» у текстах для людей
заборонено (`CLAUDE.md` п.1). Визначення — FORMULAS. Невирішені колізії назв —
FORMULAS §7.1, §7.5.

---

## 8. Якість і свіжість даних (нові вимоги, 15.10.2026)

Джерело: зовнішній аудит + власна перевірка. **Статус: вимоги, не реалізовано.**

1. **Свіжість прогнозу.** Показувати дату останнього звіту ПМа в картці (є) і
   **сигнал «прогноз застарів»**, якщо звіт старший за N днів (новий ключ
   `wr_stale_days`, пропозиція 10). Факт 15.10.2026: останні звіти DEMO — 21.09.2026
   (24 дні), сигналу немає.
2. **Відсутність даних ≠ зелений.** Вже виконано для прогнозу (S-01). Перевірити
   для актів/оплат (немає записів → не «оплата встигає»).
3. **Простежуваність.** Кожен сигнал має показувати, з яких даних він виник
   (значення плану, прогнозу, поріг). Owner View сигнали містять числа; чат отримує
   рядки «Сигнали (пораховано кодом)». Вимога: Insight/Impact/Action у чаті — лише з
   цих рядків (вже в промпті).
4. **Еталонна звірка (golden project).** Перед кожним демо/релізом: незалежний SQL-
   перерахунок F-02, F-13, F-15 із сирих таблиць проти `project_metrics`
   (запит — `CTO_CHECKPOINT_PROMPT.md`, перевірка C-3). Факт 15.10.2026: 14/14 збіг.
   Повна ручна звірка одного проєкту з Кошторисом (план) — ще не виконана.
5. **Owner Morning Flow.** Telegram → портфель → сигнал → проєкт → пояснення → джерело.
   Не пройдено власником на поточному двигуні.

---

## 9. Демо-дані (стан 15.10.2026)

14 проєктів; 9 з прогнозом ПМа (DEMO-01, 03–10); без прогнозу — DEMO-02 (немає ETC по Р)
і 4 реальні (звітів не було). Графік оплат реальних проєктів — вигаданий (рішення 13.10).
Портфель: рентабельність факт −65,5% (мало актів у демо — наслідок формули P-04),
прогноз 21,5% проти плану 25%; статуси 12 🔴 / 2 🟡 / 0 🟢. Для відео може знадобитися
досидити акти/надходження (рішення власника).

---

## 10. Межі масштабування (не блокує DEMO/пілот)

- Один тенант: таблиці без `company_id`, SQL без фільтра компанії.
- Allowlist Telegram ID зашитий у коді (3 вузли Validate + Hard Logic Engine).
- Токен бота в коді (3 вузли); RLS вимкнений на більшості таблиць.
- SQL імпорту частково збирається рядком (екранування є, параметризації немає).
- DDL (`CREATE TABLE IF NOT EXISTS`) виконується на кожне повідомлення.
Для другого клієнта потрібні: `company_id` + фільтри, права доступу з таблиці,
окремий бот/токен із сховища секретів, RLS-policies, параметризовані запити.
Рішення власника (SECURITY.md), не автоматичні фікси.

---

## 11. Відомі дефекти (15.10.2026, не виправлено)

| # | Дефект | Впевненість |
|---|---|---|
| D1 | `WR: Schedule Reminder (Fri 10:00)` без вихідних з'єднань і без дня/часу | Факт |
| D2 | Чат бачить 0 КП (порядок сестринських гілок `executionOrder v1`) | **Виправлено 15.10.2026** (§48): `Fetch KP Log Sum` → `Fetch Project Metrics` послідовно в чаті й Mini App; чат перевірено наживо (запуски 6168/6169: `kp_month = 5`), Owner View — не перевірено |
| D3 | ETC-методологія в картці (FORMULAS §7.3–7.5) | Факт (код), рішення власника |
| D4 | Чат Q6/Q7 не знає плану бюро | **Виправлено 15.10.2026** (§48): Q6/Q7 цитують `pfc`; структуру відповідей перевірено наживо 15.10.2026 |
| D5 | Кнопка «📄 Договір» іде в чат-LLM; кнопка «📄 договір X» не пройде regex | Припущення за кодом |
| D6 | Подвійні відповіді на «КП: N» / «договір X» | Припущення |
| D7 | `WR: Fetch Money Log Acts` без фільтра `статус='confirmed'` | Факт |
| D8 | Немає сигналу застарілого прогнозу | Факт |
| D9 | Дві бази рентабельності під одним підписом | Факт, рішення власника |
| D10 | Запит `Fetch Project Metrics (Chat)` не мав `m.actual_cost, m.stage_data` → у чаті `pfc.factProfit` = Σ актів (без собівартості), `factRentPct` = «—», `unpaidHours` = 0, сигнал оптимістичного ETC не рахувався (порушення §2.1 на вході) | **Виправлено 15.10.2026** (§49): запит чату ідентичний запиту Mini App; чат після правки наживо не перевірено |

Перевірено й **спростовано** (зовнішній аудит 15.10.2026): «готовність 120%» у Weekly
Render (F-22 підписано «Години до кінця / бюджет»); «акт = будь-який запис money_log»
(запит фільтрує `тип='акт_підписаний'`); розбіжність порогів між екранами (Weekly
Render і /status порогів не застосовують; резервні значення браузера = значенням БД).

---

## 12. Відкриті питання власнику

1. Рішення по FORMULAS §7 (бази рентабельності, ETC стадій, назви, P-03).
2. Поріг свіжості прогнозу (`wr_stale_days`) і чи робити сигнал.
3. Чи потрібне п'ятничне нагадування ПМам (D1).
4. Доступ до бота (SECURITY п.7), RLS, окремий бот для реального клієнта, формат `project_id`.
5. Конверсія КП як параметр (`archi_thresholds`) і повний облік КП.
6. `meeting_log`: живий фід (Circleback / ручний), гейт підтвердження.
7. Сигнал раннього відставання проєкту «в цілому» (лінійний темп заборонено; стадійний
   оптимістичний прогноз S-05 — дозволено 11.10.2026).
8. Облік годин FDO для тарифу Full.

---

## 13. Заборони

- Обчислювати показник поза двома місцями обчислення (§2.1).
- Підставляти план замість прогнозу ПМа; видавати відсутність даних за норму.
- Лінійна екстраполяція темпу проєкту (Образ результату §7); EAC/BAC як «готовність».
- Оцінювати `profitability_plan_pct` проти «галузевої норми».
- «Залишок» у текстах; метрики поза глосарієм; верстка не стовпчиком.
- Вмикати RLS / ротувати токен / обмежувати доступ без рішення власника.
- Грошові суми у Weekly Render і xlsx; зміна вигляду Weekly Render.
- Зміна коду без оновлення FORMULAS / цього документа / RELEASE_PLAN тим самим комітом.
