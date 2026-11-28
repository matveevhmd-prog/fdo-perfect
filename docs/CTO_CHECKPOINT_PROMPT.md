# ARCHI — промпт «CTO Checkpoint» v2.0 (сценарний прогін)

> Скопіювати текст нижче лінії в нову сесію Claude Code (репозиторій `fdo-perfect`, MCP `OSBB_n8n` і `Supabase`).
> Запускати: перед записом відео й показом, перед підключенням клієнта, після серії змін у n8n/Supabase (≥3 публікації).
> Версія 2.0 · 28.11.2026 (рішення власника: «роби як сказав» після зауваження, що checkpoint v1.0 був роботою заради роботи).
> Версія 1.0 (аудит коду проти документів, 7 кроків) — в історії git; лишилась як режим Б.

---

## Роль

Ти перевіряєш ARCHI **очима користувача**, а не очима коду. Питання одне: **що побачить власник, ПМ чи виконавець, і чи це правда?**
Ти нічого не виправляєш у n8n і Supabase (лише читання: `SELECT`, `get_workflow_details`, `search_workflow_executions`, `get_workflow_execution`; без `test_workflow`). Дозволені зміни — файл звіту в репозиторії.

## Правила

- Знахідка без прикладу користувача — не знахідка. Формат: **«користувач робить X → зараз отримує Y → правильно було б Z»**.
- Кожне число — з незалежного SQL (правило перевірки цифр, `CLAUDE.md`): «live SQL», «макет» або «розрахунок вручну». Макет не видавати за live.
- Методологія — лише з ID `docs/FORMULAS.md` і пунктів `CLAUDE.md` (правило 16). Немає ID — не вигадувати.
- Колір: від'ємна різниця з планом — 🔴, плюс або план — 🟢, жовтого немає (п. 15).
- Не перевірене — писати прямо.

## Режим А (основний): сценарний прогін

### Крок 0. Знімок (один рядок)
`activeVersionId` core `CKwCsGIwyw9feCY5` проти `workflows/DEMO_Archi_Agent_Core.json`; кількість вузлів; різниця `parameters`.

### Крок 1. Десять питань власника
Для кожного з 10 фіксованих питань (`WR: Determine Route`, `FIXED_Q`; Q4–Q6 — `CLAUDE.md` п. 36):
1. Візьми останню відповідь із реального виконання (`get_workflow_execution`) або прожени офлайн код вузлів на live-даних (`scripts/replay/`).
2. Незалежним SQL порахуй кожне число з відповіді.
3. Запиши рядок: **питання → цитата відповіді → число з SQL → вірно / невірно / не перевірено**.
Q4 і Q5 до W12 мають чесно відповідати «даних немає» — число вигадане = знахідка.

### Крок 2. Ранковий брифінг
Останнє виконання `J3Oqcaa2YBEsVSng`: кожен проєкт у переліку (п. 48), кожен рядок «план / факт / прогноз / різниця», колір за п. 15, кожна дія Insight → Impact → Action (п. 32). Числа — SQL; адресат дії — за п. 32; суми, яких немає в методології (п. 49), — знахідка.

### Крок 3. Owner View і Weekly Render
`replay_owner_view.js`, `replay_weekly_render.js` на live-даних: перша сторінка (P-01…P-10 із колонкою «Різниця»), картка 2–3 проєктів з різними статусами, Weekly Render без грошей (п. 7). Кожен показник — таблиця «елемент → ID у `FORMULAS` → статус» (правило 18).

### Крок 4. Дані проти незалежного розрахунку (C-3)
SQL C-3 нижче по всіх проєктах усіх компаній; будь-яка розбіжність `ac_indep ≠ ac_db` або `cf_indep ≠ cf_db` — знахідка DATA. Свіжість: `max(week_start)` по знімках (п. 26 — лише фіксувати).

### Крок 5. Те, що користувач міг не побачити
Одним рядком кожне, без пріоритетів P1/P2: «борг, на екран не впливає» (резерви порогів, старі функції, `dbg`, активні workflow без виконань, RLS/токен — стан як у `SECURITY.md`). Нове в `SECURITY.md` — окремою знахідкою лише якщо змінилось.

## Формат звіту

Файл `docs/CTO_CHECKPOINT_<дд.мм.рррр>.md` (≤ 4 КБ у чат).

```
# CTO Checkpoint — <дата>
Живий activeVersionId: … | Репо: … | Збіг: так/ні
Підсумок: питань перевірено n/10 · невірних n · кольорів неправильних n · розбіжностей C-3 n

## Сценарії (знахідки з прикладом користувача)
| # | Користувач робить | Зараз отримує | Правильно (ID, пункт) | Доказ (SQL/виконання) | Рішення від |

## Перевірено й вірно (таблиця «питання → відповідь → число з SQL»)
## Борг, на екран не впливає (по одному рядку)
## Не перевірено (чому)
## Зміни відносно попереднього checkpoint
```

Після звіту: рядок у `docs/RELEASE_PLAN.md`, коміт звіту. Код і дані не змінювати.

## Режим Б (рідко): аудит коду проти документації

Лише за прямим запитом власника або перед підключенням першого клієнта. Процедура v1.0 (кроки 0–7: інваріанти A-1…A-5, F-/S-/P-/R-check, таблиця контурів, глосарій, маршрутизація, безпека, документація) — в історії git `docs/CTO_CHECKPOINT_PROMPT.md` до 28.11.2026; звіти `CTO_CHECKPOINT_15.11`, `19.11`, `27.11.2026` — приклади. Висновки режиму Б теж подавати в форматі «користувач → зараз → правильно».

## Еталонний SQL C-3

```sql
with h as (select t.company_id, t.project_id, sum(t."години"*coalesce(r.razom_grn_god, m.real_rate_team_hour)) cost
  from time_log t join project_metrics m on m.company_id=t.company_id and m.project_id=t.project_id
  left join rates r on r.company_id=t.company_id and r.posada=t."виконавець"
  where t."статус"='confirmed' group by 1,2),
mo as (select company_id, project_id, sum("сума") filter (where "тип"='оплата_субпідряднику') sub
  from money_log where "статус"='confirmed' group by 1,2)
select m.company_id, m.project_id,
  round(coalesce(h.cost,0)+coalesce(mo.sub,0)) ac_indep, round(m.actual_cost) ac_db,
  round(coalesce(h.cost,0)+coalesce(mo.sub,0)+m.etc_forecast_total_hours*m.real_rate_team_hour
        +greatest(coalesce(m.cost_plan_subcontract,0)-coalesce(mo.sub,0),0)) cf_indep,
  round(m.cost_final_forecast) cf_db, m.profitability_forecast_pct rent_db
from project_metrics m
left join h on h.company_id=m.company_id and h.project_id=m.project_id
left join mo on mo.company_id=m.company_id and mo.project_id=m.project_id order by 1,2;
```
