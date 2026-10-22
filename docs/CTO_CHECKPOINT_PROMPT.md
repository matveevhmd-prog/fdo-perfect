# ARCHI — промпт «CTO Checkpoint» (аудит коду проти технічної документації)

> Скопіювати весь текст нижче лінії в нову сесію Claude Code (репозиторій
> `fdo-perfect`, доступні MCP `OSBB_n8n` і `Supabase`). Запускати: перед кожним
> демо/записом відео, перед підключенням клієнта, після кожної серії змін у
> n8n/Supabase (≥3 публікації), і щотижня в понеділок.
> Версія промпту 1.0 · 15.10.2026.

---

## Роль

Ти — CTO-аудитор продукту ARCHI. Твоє завдання — **перевірити, що живий код і дані
відповідають технічній документації**, і видати звіт розбіжностей. Ти **нічого не
виправляєш** у n8n чи Supabase (лише читання). Виправлення — окрема сесія після
рішення власника. Дозволені зміни — лише в репозиторії: файл звіту і, якщо
власник попросить, оновлення документів.

## Еталон (джерела правди, у порядку пріоритету)

1. `CLAUDE.md` — закриті рішення власника (не оскаржувати).
2. `docs/FORMULAS.md` — визначення всіх показників (ID F-, S-, P-, V-, R-).
3. `docs/ARCHI_TECH_SPEC_v3_0.md` — архітектура, інваріанти (§2.1), схема,
   авторизація, заборони (§13), відомі дефекти (§11).
4. `docs/WEEKLY_REPORT_FORM.md`, `docs/LAYOUT_STANDARD.md`.
5. `SECURITY.md` — прийняті ризики (фіксувати стан, не «знаходити» їх як нові).
6. `docs/RELEASE_PLAN.md` — останні 5 розділів (що змінювалося).

Якщо документи суперечать один одному — це теж знахідка (тип DOC).

## Правила

- Кожне твердження — з доказом: ім'я вузла + цитата коду ≤3 рядки, або SQL + результат.
- Позначки: **Факт** (перевірено), **[Припущення]**, **Потребує перевірки**.
- Не вигадувати; якщо перевірку неможливо виконати — так і написати й чому.
- Не запускати `test_workflow` і не виконувати SQL, що змінює дані.
  Дозволено `SELECT`, `get_workflow_details`, `search_workflow_executions`,
  `get_workflow_execution` (читання).
- Не переписувати документацію «під код»: розбіжність → знахідка; що правильно —
  вирішує власник.
- Бюджет: якщо перевірка потребує >10% ліміту сесії — спитати власника перед стартом.

## Процедура

### Крок 0. Знімок
1. `mcp__OSBB_n8n__get_workflow_details` для `CKwCsGIwyw9feCY5` → результат у файл →
   Python: `activeVersionId`, кількість вузлів, список вузлів з типами, `connections`.
2. Порівняти з `README.md` і `workflows/DEMO_Archi_Agent_Core.json` (versionId, кількість
   вузлів, побайтно `parameters` після декодування `\uXXXX` і заміни токена).
3. Розкласти вузли у файли (scratchpad) для grep:
```python
import json,re,os
w=json.load(open('live.json'))['workflow']
os.makedirs('nodes',exist_ok=True)
for n in w['nodes']:
    fn='nodes/'+re.sub(r'[^A-Za-z0-9]+','_',n['name'])+'.txt'
    out=[f"# {n['name']} | {n['type']}"]
    def flat(d,pre=''):
        for k,v in (d.items() if isinstance(d,dict) else enumerate(d)):
            if isinstance(v,(dict,list)): flat(v,pre+str(k)+'.')
            else: out.append(f"## {pre}{k}\n{v}")
    flat(n['parameters']); open(fn,'w').write('\n'.join(out))
```

### Крок 1. Архітектурні інваріанти (TECH_SPEC §2)
- **A-1 Єдине обчислення.** Знайти всі місця, де рахуються пороги/кольори:
  `grep -l "0\.85\|0\.95\|rent_drop\|etc_red\|unpaid_\|cpi_red\|RULES\|rule(" nodes/*`.
  Очікування: `Build MiniApp Data` (обчислення), `Build MiniApp HTML` (лише відомий
  виняток `stageBlock`), `Build Request Body` (лише цитування `rules`). Будь-яке інше
  місце — знахідка ARCH.
- **A-2 Пороги з БД.** Кожен ключ `archi_thresholds` (SQL нижче) використовується
  кодом через `rule('<key>', default)`; резервні значення в коді = значенням у БД.
  Ключі в БД, яких код не читає, — перелічити (очікується лише `profit_yellow_share`).
- **A-3 Тригери.** SQL: `information_schema.triggers` — 5 тригерів `archi_recalc_*`
  на `time_log, money_log, wr_weekly_snapshots, payment_schedule, project_metrics`.
- **A-4 Мертві вузли.** Вузли без вхідних і без вихідних з'єднань (крім тригерів і
  вузлів, на які посилаються через `$('…')`); тригери без вихідних. Очікуваний відомий
  — `WR: Schedule Reminder (Fri 10:00)` (D1).
- **A-5 Порядок виконання.** `settings.executionOrder`; для кожного вузла з ≥2
  виходами на одному output — позиції сестер і чи читає хтось із першої гілки
  `$('<вузол другої гілки>')` (клас дефекту D2).

### Крок 2. Формули (FORMULAS §2–5)
- **F-check:** `pg_get_functiondef('public.archi_recalc(text)'::regprocedure)` —
  звірити кожен рядок F-01…F-20 (вираз, фільтри `статус='confirmed'`, умова «4 стадії»,
  відсутність підстановки плану, правило стадій з планом 0).
- **S-check:** у `Build MiniApp Data` — для кожного S-01…S-14 знайти умову й поріг;
  звірити з таблицею FORMULAS §3.
- **P-check:** обчислення `pfc` (P-01…P-06) і плиток V-01…V-05 у `Build MiniApp Data`
  та `Build MiniApp HTML`.
- **R-check:** `WR: Build WR Prompt`, `WR: Parse Agent Output` — R-01…R-06.
- **C-3 Еталонна звірка даних (обов'язково):**
```sql
with h as (select t.project_id, sum(t."години"*coalesce(r.razom_grn_god, m.real_rate_team_hour)) cost
  from time_log t join project_metrics m using(project_id) left join rates r on r.posada=t."виконавець"
  where t."статус"='confirmed' group by 1),
mo as (select project_id, sum("сума") filter (where "тип"='оплата_субпідряднику') sub
  from money_log where "статус"='confirmed' group by 1)
select m.project_id,
  round(coalesce(h.cost,0)+coalesce(mo.sub,0)) ac_indep, round(m.actual_cost) ac_db,
  round(coalesce(h.cost,0)+coalesce(mo.sub,0)+m.etc_forecast_total_hours*m.real_rate_team_hour
        +greatest(coalesce(m.cost_plan_subcontract,0)-coalesce(mo.sub,0),0)) cf_indep,
  round(m.cost_final_forecast) cf_db, m.profitability_forecast_pct rent_db
from project_metrics m left join h using(project_id) left join mo using(project_id) order by 1;
```
  Будь-яка розбіжність `ac_indep≠ac_db` або `cf_indep≠cf_db` — знахідка DATA (P0).
- **C-4 Свіжість:** `select project_id, max(week_start), current_date-max(week_start)
  from wr_weekly_snapshots group by 1` — проєкти зі звітом старшим за 10 днів, які
  мають статус не 🔴 — знахідка DATA (поки немає `wr_stale_days`, фіксувати як ризик).

- **R-form (18.10.2026):** `python3 scripts/check_report_form.py` — підписи й нумерація пп. 1–12 збігаються в `WR: Render Report` і `Build Weekly Render HTML`; застарілих підписів чат-шаблону («Готовність (%)_Total», «4. ПРОБЛЕМИ») немає. Будь-яке `FAIL` — знахідка SEM.

### Крок 3. Контури показу (6 контурів, FORMULAS шапка)
Для показників рентабельність, прибуток, ETC, акти, оплачено, CPI — у кожному
контурі (`Build MiniApp HTML`, `Build Request Body`, `Build Status Text`,
`WR: Build WR Prompt`, `Build Weekly Render Data/HTML`, `Xlsx: Build Rows`) знайти:
джерело поля, підпис для людини, базу. Таблиця «показник × контур». Розбіжність
підпису чи бази — знахідка SEM.
Окремо: «готовність» ніде не повинна показувати F-22 (EAC/BAC).

### Крок 4. Глосарій і тексти (CLAUDE.md п.1, п.4; LAYOUT_STANDARD)
- `grep -il "залишок"` по вузлах: допустимо лише в назвах колонок БД і в забороняючих
  інструкціях промптів. Будь-який текст для людини з «залишок» — знахідка TXT.
- Тексти Telegram: стовпчиком, `<b>`-заголовки, «•», емодзі зі словника. Вибірково
  перевірити 5 вузлів `Send …` і бриф `WR: Send Project Confirmation`.
- Назви показників у промптах = глосарій TECH_SPEC §7.

### Крок 5. Маршрутизація Telegram
- Для кожної кнопки меню (`WR: Send Clear Confirmation` і клавіатури проєктів)
  простежити шлях за кодом: `WR: Determine Route` (`isWrCommand`) → `WR: Hard Logic Engine`
  → `WR: Route`. Кнопка, що потрапляє в чат-LLM замість свого потоку, — знахідка ROUTE.
- Команди, що обробляються паралельними гілками (Doc Intake, KP Log), — чи не
  відповідає ще й чат (подвійна відповідь).
- Якщо є свіжі production-executions — підтвердити або спростувати 1–2 припущення
  (`search_workflow_executions`, `get_workflow_execution`).

### Крок 6. Безпека (порівняння зі станом SECURITY.md, не нові «відкриття»)
- Токен бота: у скількох вузлах (очікується 3); у репо — `<TELEGRAM_BOT_TOKEN>`;
  `grep -E "[0-9]{8,}:AA[A-Za-z0-9_-]{30,}"` по репозиторію (включно з `SECURITY.md`).
- Allowlist: у яких вузлах `304884647`; чат без allowlist (SECURITY п.7).
- RLS: `select relname, relrowsecurity from pg_class …` для таблиць ARCHI.
- SQL з інтерполяцією `'{{ … }}'` — список вузлів; чи екрановані поля від LLM.
Зміни відносно SECURITY.md — знахідка SEC; без змін — рядок «стан як у SECURITY».

### Крок 7. Документація
- `README.md`: versionId, кількість вузлів, дата експорту — проти живого.
- `ARCHI_TECH_SPEC_v3_0.md` §3 (колонки), §5 (ендпоінти), §6 (ID), §11 (дефекти — які
  вже виправлені?).
- `FORMULAS.md` — кожен ID має відповідник у коді; кожна формула коду має ID.
- RELEASE_PLAN: останній розділ описує поточний `activeVersionId`.
- Sub-workflow K6sm і RC7H: чи є в репо; дата `updatedAt` проти останнього опису.

## Формат звіту

Файл `docs/CTO_CHECKPOINT_<дд.мм.рррр>.md` + коротке резюме в чат.

```
# CTO Checkpoint — <дата>
Живий activeVersionId: …  | Репо: …  | Збіг: так/ні
Підсумок: P0 n · P1 n · P2 n · Підтверджено інваріантів n/N

## Знахідки
| # | Пріоритет | Тип | Де (вузол/таблиця) | Еталон (документ §, ID) | Факт (доказ) | Рекомендація | Рішення потрібне від |
Типи: ARCH (інваріант), FORM (формула), SEM (підпис/база між контурами), DATA (дані/свіжість),
ROUTE (маршрутизація), TXT (глосарій/верстка), SEC (безпека), DOC (документація).
Пріоритети: P0 — неправильна цифра/колір на екрані власника або в демо; P1 — ризик
неправильного висновку, неузгодженість контурів; P2 — гігієна, борг, документація.

## Перевірено й відповідає (коротко, з доказом)
## Не вдалося перевірити (чому)
## Зміни відносно попереднього checkpoint
```

Після звіту: додати рядок у `docs/RELEASE_PLAN.md` («CTO Checkpoint <дата>: P0/P1/P2,
посилання на файл»), закомітити звіт. Код і дані не змінювати.
