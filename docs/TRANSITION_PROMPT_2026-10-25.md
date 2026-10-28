# ARCHI — перехідний промпт для нової сесії Claude Code
## Дата: 25.10.2026 | Версія: v3 (ред. 2, повна; замінює `TRANSITION_PROMPT_2026-10-15.md` v1 і першу коротку редакцію цього файлу)

> **Як читати.** Це вхідний документ для нової сесії. Він не замінює `CLAUDE.md` (закриті рішення власника п. 1–9, ритуал старту, заборони — читати першим), а дає повну картину: де ми → що робити далі → продукт → рішення → інфраструктура → архітектура → тижневий звіт (найскладніша частина) → формули → що зроблено → як перевіряти → відкриті питання → як технічно працювати → уроки → заборони.
> Позначки: **Факт** — перевірено кодом/SQL/скрінами; **[Припущення]** — висновок без перевірки; **Потребує перевірки** — є сумнів.
> **Оновлення 28.10.2026 (рядок версії за правилом `CLAUDE.md` «Перехідний промпт»; повна v4 — після ≥ 3 нових публікацій):** n8n `CKwCsGIwyw9feCY5`, **`activeVersionId 5fb18a4d-834c-4c90-adc0-560431bd5808`**, 179 вузлів. З 25.10: `769bc540` (4 вузли: `WR: Inbox Add`, `Import: Insert Time Rows`, `Import: Insert Money Rows`, `Meeting: Insert Rows`, §116) і `4d403691` (`WR: Save Weekly Snapshot`, `WR: Save Next Week Plan`, §118) і `b9d271f5`, `ee1224bf`, `5fb18a4d` (`Build MiniApp HTML`: «КП, надіслано» і «Договори, підписано» внизу таблиці портфеля, §123–§125; на екрані портфеля лише рентабельність від контракту — таблиця і плитки вкладки «Рентабельність») — вільного тексту ПМа в інтерпольованому SQL більше нема; вузлів Postgres 47: параметри 13, інтерполяція 21 (лише `chat.id` і `project_id`), статичних 13. **Задача розділу 1 нижче виконана.** Поточна задача — **демо (Ф1): показ вівторок 03.11.2026, глядачі — власники АБ-компаній**; план — `docs/DEMO_PLAN_2026-10-28.md` і `docs/DEMO_REPORT_TEXTS_2026-10-30.md` (§119); методологія оцінки змін SQL — `docs/SESSION_PLAN_2026-10-27_SQL_PARAMS_BLOCK_A.md`. Робочі правила сесії — `CLAUDE.md` (розділ від 28.10.2026). Відкриті знахідки: вихід помилки `WR: Save Weekly Snapshot` не підключений; підпис «Станом на» береться з `data_updated_at`; Owner Morning Test не пройдено.
> **Живий стан на 25.10.2026:** n8n `CKwCsGIwyw9feCY5`, `activeVersionId 8a9fe9e5-5609-42cc-8b1b-eebef70b0d7a`, 179 вузлів, `timezone Europe/Kyiv`; репозиторій `matveevhmd-prog/fdo-perfect`, гілка `main` = живий стан (на момент підготовки). **Не довіряй цьому рядку мовчки — звір (розділ 0, крок 5).**

## Анкери (формат skill `doc-unification`)

**RETRIEVAL_STATUS:** н/д — ARCHI не має retrieval-бази; WBS-документа немає, еталон стану — `docs/RELEASE_PLAN.md` (читати з кінця).

**BLOCKERS** (ID дослівно з `docs/CTO_CHECKPOINT_25.10.2026.md`, стан після виправлень #2–#4):
- #1 (P1, ARCH) — пороги й кольори дублюються в `AN: Attach Block` — відкрито, потрібне рішення/ітерація.
- #4 (P1, SEC) — чинний токен бота був у публічній git-історії з 17.10.2026; з HEAD прибрано (PR #73); **ротація не зроблена — рішення власника**.
- #5 (P2, ARCH) — Doc Intake читає `$('WR: Read Mode')` із сестринської гілки (залежить від координат вузлів на полотні).
- #6 (P2, DATA) — ключі `archi_thresholds` без читача: `demo_asof`, `plan_fx_uah_usd`, `profit_yellow_share`.
- #7 (P2, DATA) — застарілі тижневі звіти (12 з 13 проєктів ≥ 13 днів; D8: сигналу нема).
- #9 (P2, ARCH) — `WR: Schedule Reminder (Fri 10:00)` без вихідних (D1).
- Закрито 25.10: #2, #3 (документація), #8 (округлення 1 грн).

**AGENTS_TABLE:** без змін. Чат власника — Anthropic `claude-sonnet-4-6` (`Build Request Body → Call Anthropic → Sanitize Reply`, `max_tokens 2600`, `temperature 0.2`). `WR: Agent`, `Import: Agent`, `Meeting: Agent` — OpenAI `gpt-4o` + Postgres Chat Memory (ключ `<chat_id>_wr_<project_id>` / `_import_` / `_meeting_`, вікно 30, таблиця `n8n_chat_histories`). Голос — OpenAI transcribe, фото — `gpt-4o`.

**NEXT_LEVEL:** єдиного «рівня» нема. Пріоритет (SWOT 25.10.2026): надійність існуючого — параметризація SQL → сигнал застарілого звіту (D8) → єдині пороги (#1). **EVM (класичний):** власник обрав окрему сесію (26.10.2026); план — `docs/EVM_CLASSIC_PLAN.md`, стартовий промпт — `docs/START_PROMPT_EVM_S0.md`; розділи RELEASE_PLAN цієї роботи — «EVM-0, EVM-1, …».
**Призупинено до рішення власника:** вкладка «EVM (класичний)» (реалізація — після Р1–Р11), комерціалізація, рядок «Факт» у таблиці «Гроші», ротація токена, allowlist на вхід бота.

---

## 1. МЕТА НАСТУПНОЇ СЕСІЇ

**Задача (одна):** перевести на параметризований SQL (`queryReplacement`, `$1…$n`) вузли, куди йде вільний текст ПМа: `WR: Inbox Add`, `Import: Insert Time Rows`, `Import: Insert Money Rows`, `Meeting: Insert Rows`. **Статус: пропозиція Claude (SWOT 25.10), власник ще не підтвердив — першим кроком спитати «робити?» (одне запитання).** Якщо власник назве інше — працювати за його словом.

**Критерій успіху:** (1) у цих 4 вузлах немає `'{{ … }}'` у тілі запиту, значення йдуть через `queryReplacement`; (2) `node tests/wr_parse_agent_output/run.js` → «OK: пройдено 29, провалено 0»; (3) live-прогін власника в Telegram (п. 1.5) пройдено; (4) репозиторій синхронізовано (JSON з заглушкою токена, README, TECH_SPEC, RELEASE_PLAN §116) і злито в `main`.

## 1.5. ПЛАН РОБОТИ ТА СПОСІБ ПЕРЕВІРКИ

> **Розгорнутий план сесії й план перевірки (15 кроків, 5 live-прогонів, критерій «виконано») — `docs/SESSION_PLAN_2026-10-26_SQL_PARAMS.md`.** Коротка версія нижче; у разі розбіжності діє розгорнутий файл.

**План (по порядку; перехід до наступного кроку — коли попередній підтверджено):**
1. Прочитати `CLAUDE.md`, цей файл, `docs/RELEASE_PLAN.md` §104–§115, `SECURITY.md` п. 1 (правило експорту токена), `docs/CTO_CHECKPOINT_25.10.2026.md`.
2. Спитати власника: (а) чи робити параметризацію 4 вузлів; (б) чи брати до цієї сесії ротацію токена (рішення власника, не Claude).
3. Звірити живий стан: `get_workflow_details` (результат ≈ 340–670 тис. символів → зберігається у файл, читати Python-ом) → `activeVersionId` має бути `8a9fe9e5-5609-42cc-8b1b-eebef70b0d7a` і збігатись із `workflows/DEMO_Archi_Agent_Core.json`; якщо ні — довіряти живому n8n.
4. Зняти код кожного з 4 вузлів із файла експорту, описати поточні поля (`session_id`, `project_id`, `source_type`, `content` тощо), переписати запит на `$1…`, `queryReplacement` — масивом виразів; семантику не змінювати (`ON CONFLICT`, `WHERE length(trim(...)) > 0`, підрахунок «У черзі: N»).
5. Перевірити на значеннях з апострофами, подвійними лапками, `\`, `$1`, новим рядком і емодзі — SELECT-копією запиту в Supabase (лише читання) та у чернетці n8n.
6. `update_workflow` (`versionName` ≤ 80 символів) → `get_workflow_details` → **побайтове порівняння** чернетки з тим, що надсилали → `publish_workflow`.
7. Експорт у репозиторій: `nodes/connections/settings`, `versionId = activeVersionId`, `activeVersion`, **заміна токена на `<TELEGRAM_BOT_TOKEN>`**; перевірка `grep -rE "[0-9]{8,}:AA[A-Za-z0-9_-]{30,}" --exclude-dir=.git .` → 0 рядків; README/TECH_SPEC (рядок версії), RELEASE_PLAN §116, PR → merge.
8. Дати власнику гайд для Telegram у стилі ASD-STE100 (речення ≤ 20 слів, одна дія на крок, дані стовпчиком).

**СПОСІБ ПЕРЕВІРКИ (10/10, не «status: success»):**
- Код у n8n = файл, який надсилали (Python, `==`).
- `node tests/wr_parse_agent_output/run.js` → «OK: пройдено 29, провалено 0»; `python3 scripts/check_report_form.py` → «Розбіжностей: 0».
- **Live (власник, DEMO-03):** «🆕 Новий» → надіслати повідомлення зі спецсимволами: `Дедлайн ЕП 06.11.2026; "лапки" і 'апострофи', слеш \ і $1` → «📤 Відправити». Очікувано: «Прийнято · У черзі: 1» без помилки; запис у `archi_wr_inbox` **дослівно** (`select content from archi_wr_inbox order by id desc limit 1`); execution у n8n без помилок.
- **Import і Meeting:** окремі live-прогони (кнопки «⏱ Години і гроші» / «🤝 Зустріч»); очікуване число рядків у `time_log` / `money_log` / `meeting_log` Claude називає власнику **до** тесту (як у тестовому повідомленні), після — звіряє SQL.
- Нічого не видавати за перевірене, що не виконано наживо; кожне число — з джерелом («live SQL», «макет», «розрахунок вручну»).

**Відкриті питання до Андрія (не вирішувати самому):** ротація чинного токена; allowlist на вхід `Telegram Trigger` (зараз бот відповідає будь-кому); скорочення `MAX_AGE` initData (24 год); старт вкладки «EVM (класичний)»; комерціалізація (консалтинг чи SaaS); рядок «Факт» (акти − собівартість) у таблиці «Гроші»; що робити з тестовим знімком DEMO-03 id 217.

## 1.6. FEEDBACK LOOP ПІСЛЯ PUBLISH

Публікації сесії 25.10.2026 (n8n `CKwCsGIwyw9feCY5`):

| Версія | Що | Наживо перевірено |
|---|---|---|
| `e3984607` → `cc94785c` | варіант Б: числа/дати/блокер лише з тексту ПМа, привʼязка до стадій (§104–§111) | ✅ власник, DEMO-03; знімок id 217 збігся з текстом |
| `5dce6355` | план наступного тижня по рядках (SQL у 4 вузлах) | ✅ картка 24-52 |
| `17760093` | без дубля «ПМ підтвердив» (SQL у 2 вузлах) | ✅ картка 24-52 (після повного перезапуску Mini App — кеш WebView) |
| `8a9fe9e5` | `TODAY` за Києвом у `Build MiniApp Data` + `timezone Europe/Kyiv` | ❌ **наживо не перевірено** |

**Перевірити факт `8a9fe9e5` до 01.11.2026:** (а) картка Owner View проєкту з блокером — «днів простою» збігається з календарем за Києвом (SQL: `select blocker from wr_weekly_snapshots`, розрахунок вручну); (б) у понеділок до 07:00 за Києвом новий звіт створює `week_start` цього понеділка (`select week_start, created_at from wr_weekly_snapshots order by id desc limit 3`). Якщо розрив — назвати прямо, не «дрібниця».
**Наступний повний CTO Checkpoint** (`docs/CTO_CHECKPOINT_PROMPT.md`) — 01.11.2026 (щопонеділка) або після ≥ 3 публікацій. 25.10 не виконано: S/P/V-check рядок за рядком, таблиця «показник × контур», верстка 5 вузлів `Send …`, чинність токена.

---

## КАРТА — де ми зараз (читати до деталей)

ARCHI має **три різні фінали**. Не змішувати: робота для одного не просуває інший.

| Фінал | Зміст | Стан на 25.10.2026 |
|---|---|---|
| **Ф1. Демо-відео для клієнта** (`docs/DEMO_VIDEO_PLAN.md`) | Owner View + Archi Consult + тижневий ритм на демо-даних бюро «50 виконавців» | Дані й сценарії для 14 проєктів зібрано (§62–§69); Owner View і Weekly Render відполіровано; **Owner Morning Test** (`docs/OWNER_MORNING_TEST.md`) і запис відео — не пройдено/не знято. Останні 10 днів власник працював над **надійністю тижневого звіту ПМа** (§76–§111), а не над відео |
| **Ф2. Реліз** (`RELEASE_PLAN` §0, 7 пунктів одночасно) | Наскрізний тижневий цикл на реальному календарі + Owner Morning Test | Чекпоінти 1–3 ✅ (13.09); чекпоінт 4 — відкритий |
| **Ф3. Перший реальний клієнт** (`RELEASE_PLAN` §10) | Окремий бот, RLS, формат `project_id`, ролі «виконавець / ПМ» (§55) | Блокують **рішення власника** (RLS, токен, доступ до бота) — не чіпати без нього |

**Діагноз.** З 15.10 по 25.10 зроблено дуже багато в тижневому звіті, EVM-кольорах і Weekly Render, і майже нічого — для Ф1 (запис відео) і Ф3. Нова сесія, яка бере черговий рядок таблиці Weekly Render без запиту власника, — тунельність. Якщо власник сам не назвав задачу — запропонувати їх по порядку: (1) параметризація SQL (надійність), (2) Owner Morning Test + демо-сценарій, (3) D8 застарілі звіти.

---

## 0. Перші 15 хвилин нової сесії (порядок дій)

1. `CLAUDE.md` повністю (п. 1–9; ритуал старту; заборони). Якщо розділу «ARCHI — ЗАФІКСОВАНІ РІШЕННЯ ВЛАСНИКА» не видно — ти на чужому репозиторії/гілці: зупинись і скажи першим рядком.
2. Цей документ повністю.
3. `docs/RELEASE_PLAN.md` — з кінця: §104–§115 (варіант Б, тести, CTO 25.10), далі за потреби §76–§103 (єдина форма звіту, PX-01, EVM-ланцюжок, кольори, черга).
4. `docs/WEEKLY_REPORT_FORM.md` і `docs/LAYOUT_STANDARD.md` — **перед будь-якою зміною тексту, який бачить користувач** (власник ловив сесії на переробці блоку звіту без прочитання форми). `docs/FORMULAS.md` — перед зміною формули, порогу чи підпису.
5. Звірити живий `activeVersionId` (`mcp__OSBB_n8n__get_workflow_details`) з `README.md`, `workflows/DEMO_Archi_Agent_Core.json`, §1.6 цього файлу. Розбіжність → довіряти n8n і переекспортувати.
6. Прогнати тести: `node tests/wr_parse_agent_output/run.js`, `python3 scripts/check_report_form.py`.
7. Лише після цього — будь-які зміни. Перед **будь-якою** пропозицією назвати (правило власника): (а) де це в плані/«Карті»; (б) що з уже підключеного воно зачіпає; (в) чи не створює нового боргу; (г) чи масштабується на N проєктів. Якщо не знаєш — сказати «не перевірив вплив на X, Y, Z».

**Еталон технічної правди:** `docs/ARCHI_TECH_SPEC_v3_0.md` + `docs/FORMULAS.md`. `ARCHI_TECH_SPEC_v2_0.md` і `TRANSITION_PROMPT_2026-10-15.md` — історія (див. розділ 11: де вони застаріли).

---

## 2. Продукт, власник, стиль

**ARCHI** — оркестраційний шар над проєктними даними архітектурного бюро (не ERP, не таск-менеджер): читає **план** (Кошторис у Google Sheets), **факт** (журнали годин і грошей), **прогноз** (тижневий звіт ПМа), рахує крос-перевірки й віддає власнику:
1. **Owner View** — Telegram Mini App (портфель + картка проєкту, гроші).
2. **Archi Consult** — чат-агент у Telegram (питання Q1–Q10 + довільні; формат Insight–Impact–Action).
3. **Щотижневий ритм** — звіт ПМа через бота → **Weekly Render** (таблиця для наради **без грошей**) → xlsx.

**Дві незалежні методології (`CLAUDE.md` п. 8):** Archi (основна; Owner View, Weekly Render, чат ПМа) і класичний EVM (окрема вкладка — **не реалізовано**). Обидві рентабельності (від контракту і від собівартості) зберігаються: є pro bono / частково оплачувані проєкти.

**Тарифи (TECH_SPEC §1):** Light $500/міс (до 8 проєктів), Full $1 000/міс (до 20). Чесно обіцяти: регулярну видимість портфеля, не обіцяти управління ліквідністю/касовим розривом.

**Власник:** Андрій Матвєєв, COO, Telegram id `304884647`. Спілкування — українською, без води, «zero fluff». Чесність: факт/припущення позначати; відповідь без даних — «Не маю достатньо даних» + пошук. Стиль відповідей: **дані стовпчиком, не рядком** (п. 4, діє й на відповіді Claude); для стратегічних тем — блоки «💡 Порада Claude» і «🎓 Вчитель»; гайди для тестів — ASD-STE100 (речення ≤ 20 слів, одна дія на крок, очікуваний результат після кроку). Надсилає скріни з рукописними позначками без тексту — **не вгадувати сенс**, назвати 2–3 варіанти й спитати. Питати «продовжувати?» перед кроком, що спалює > 10% ліміту сесії. Не пропонувати обрізаних рішень і не латати технічну проблему обхідним шляхом — проблема = сигнал, що архітектура неправильна.

---

## 3. Закриті рішення власника (не перепитувати)

З `CLAUDE.md` (дослівно там; тут конспект):
1. Термін тільки **ETC** (ETC_план / ETC_факт / ETC_прогноз); «Залишок» прибрано (колонки БД `залишок_прогноз_*` — технічні назви, у UI показуються як ETC).
2. Флоу тижневого звіту: кнопка проєкту → перелік питань → довільні відповіді (текст/голос/фото/документ) → «Відправити» → Archi структурує, показує форму, питає, чого бракує → «відповіді нема» дозволено.
3. Не повертатись до «Weekly Render: шрифти/вигляд» (спец — `WEEKLY_REPORT_FORM.md` §2; зміна вигляду = зміна специфікації тим самим комітом).
4. Верстка **тільки стовпчиком** (`LAYOUT_STANDARD.md`).
5. `docs/FORMULAS.md` оновлювати тим самим комітом при зміні формули/порогу/підпису.
6. Репозиторій і гілка (лише `fdo-perfect`; кінець сесії = PR + merge).
7. EVM — методологічна база. Weekly Render **без грошей**. Ланцюжок готовності: Витрачено = AC/BAC; Готовність ПМа = EV/BAC; За прогнозом = AC/EAC; Ефективність годин = BAC/EAC. Колір: 🟢 краще/за планом, 🟡/🔴 гірше; виняток — узгодженість (≥ 10 п.п. в обидва боки → 🔴). Індекси: жовтий < 0,9, червоний < 0,7; ETC Δ > 5% / 10% від BAC. Колір рахує лише SQL.
8. Дві методології; обидві рентабельності; «виконано роботи відносно грошей» = Готовність ПМа (E-02) і «Виставлено ÷ освоєне» (E-06b).
9. **Варіант Б:** числа, дати й блокер у звіті ПМа — лише з тексту ПМа; перевірку виконує код; слова «нуль/завершено/без змін» — лише по названій стадії; непідтверджене прибирається й показується блоком «Не підтверджено вашим текстом».

**Рішення 10.10–25.10.2026 (джерело — RELEASE_PLAN):**

| Дата | Рішення | Де |
|---|---|---|
| 10.10 | Прогноз лише від ПМа; немає ETC по стадії < 100% → прогноз NULL, завжди 🔴, план не підставляється | §16 |
| 11.10 | Прибуток факт = підписані акти − собівартість факт; «Оптимістичний прогноз ПМа» (ETC < плану на 40% при готовності < 50%) → 🟡 | §30, §33 |
| 13.10 | Стадії без плану (ETC_план 0) не питаються: готовність 100, ETC 0 | §36 |
| 14–16.10 | Рентабельність — головний показник; бізнес 25% = прибуток / собівартість; дві проєкції; «Виконані роботи» = собівартість факт; КП-конверсія 20% (1 з 5) | §38–§58 |
| 16.10 | CPI за годинами; ETC/Прибуток План/Факт/Прогноз; картка План \| Факт \| Прогноз | §57–§58 |
| 17.10 | АН — окремий договір «оплата за виїзд» (`contract_type='visit'`), не входить у портфельні розрахунки; демо-дата показу замінена на «станом на дату оновлення даних» (F-28, 18.10) | §62–§71 |
| 18.10 | Єдина форма звіту скрізь (чат ПМа = Weekly Render = xlsx); «План тижня» — контур керування PX-01 (пороги 70/50); «Фінал» вирішує код, не LLM | §76–§77 |
| 20–22.10 | ETC-трійка + Δ; EVM-ланцюжок; напрям кольору «зелене = краще за план»; CPI прибрано з Weekly Render; самоаудит R1–R5: узгодженість в обидва боки, база ETC Δ = BAC, «Ефективність виконання», акти — за планом актів | §79–§86 |
| 24.10 | S-04 в Owner View — з SQL; прогноз року — лише колір шрифту (червоний кидається в очі); «Прибуток» над рентабельностями | §87–§91 |
| 24–25.10 | **Черга повідомлень ПМа** (варіант А): обробка лише по «Відправити»/«Фінал»; «Фінал» без даних відхиляється до LLM | §93–§98 |
| 25.10 | Дані — стовпчиком; обидві рентабельності; окрема вкладка EVM; «Факт» у «Гроші» — відкрите | §101 |
| 25.10 | Варіант Б (п. 9); блокер/тип/дата — лише зі слів ПМа; `CLAUDE.md` п. 9 | §104–§111 |

---

## 4. Інфраструктура (реєстр)

| Компонент | ID / значення | Стан / примітка |
|---|---|---|
| n8n | `osbbcopilot.app.n8n.cloud` (MCP-сервер `OSBB_n8n`) | вебхуки з контейнера недоступні (проксі); виконання бачить лише MCP |
| Головний workflow | `CKwCsGIwyw9feCY5` «DEMO Archi Agent (Core: Chat + MiniApp)» | active `8a9fe9e5-5609-42cc-8b1b-eebef70b0d7a`, 179 вузлів, 7 тригерів, `executionOrder v1`, `timezone Europe/Kyiv` |
| Koshtorys Ingest | `K6smBd5xWZLWx9rr` (16 нод; гілка `AN:` для вкладок `<id>-АН`) | JSON у репо **немає** |
| Document Intake | `RC7HNVlJtuPLtvYV` | JSON у репо **немає** |
| Sheets Helper | `nGcSyWfuMO7vjTn6` («Archi: Sheets Helper», ручний; credential Google Sheets) | правки Кошторису |
| Representative Bot | `I3K5tBj0FWF1dbWb` | **не чіпати** |
| Protocol Format Helper | `LK4tBGMPiwIgpoki` | inactive, у репо (`workflows/Archi_Protocol_Format_Helper.json`) |
| Supabase | проєкт `bxawceksdkqlbkdgjvyz` | `execute_sql` на **запис** може таймаутити (чекає підтвердження власника) — DELETE/UPDATE виконує власник у SQL Editor; читання працює; `apply_migration` працює |
| Бот | `@archi_demo_bot`, `BOT_ID 8813476306` | токен — у вузлі `M: Send Project Picker` (живий n8n); у репо — `<TELEGRAM_BOT_TOKEN>` |
| Allowlist | `304884647` | `Validate InitData`, `WR-Render: Validate InitData`, `Xlsx: Validate InitData`, `WR: Hard Logic Engine` («кошторис»/«затвердити») |
| Google | Кошторис DEMO `1Ok4_U9u8kLZ0GJarPbEk4nQsqKeqdLzNNBONNNDgF7g`; Drive-папка демо-договорів `14clHqV31gvGyovMlxzvtF53kzzMf2zyF` | Google Sheets MCP бува недоступний — Кошторис правити через n8n/Drive |
| Webhooks (`/webhook/…`) | `demo-archi-owner-view` (HTML, без auth), `demo-archi-owner-view-data` (JSON, initData), `demo-archi-weekly-render`, `demo-archi-weekly-render-data` (initData), `demo-archi-export` (xlsx, GET, initData) | initData іде в URL (відомий недолік) |
| Авторизація Mini App | Ed25519-підпис Telegram (`crypto.verify(null, …)`, публічний ключ Telegram; **токен не потрібен**) + `auth_date` обов'язковий і < 86400 с + allowlist | чат і WR-бот — **без allowlist** (SECURITY п. 7; рішення власника) |
| Пам'ять агентів | `n8n_chat_histories`, ключі `<chat_id>_wr_<project_id>` / `_import_` / `_meeting_`, вікно 30 | не чиститься автоматично; «Новий» видаляє сесію |
| Власник Telegram | id `304884647`, `citydesign_ua` | — |

---

## 5. Архітектура даних і SQL-шар

```
Кошторис (Sheets) ──K6sm («кошторис X» → «затвердити»)──┐
Звіт ПМа (Telegram, WR) ─► archi_wr_inbox ─► (Відправити/Фінал) ─► wr_weekly_snapshots ┤
Імпорт годин/грошей ─────► time_log / money_log ───────────────────────────────────────┤─► тригери archi_recalc_* ─► project_metrics
Графік оплат ────────────► payment_schedule ───────────────────────────────────────────┤        (archi_recalc → archi_recalc_stages / _visit)
Пороги і план бюро ──────► archi_thresholds (31 ключ)                                  ┘
                                  │
        SQL-в'ю: archi_report_today · archi_snapshot_history · archi_plan_execution
        SQL-функції сигналів: archi_vac_signal · archi_ready_gap_signal · archi_acts_plan · archi_idx_signal · archi_snapshot_metrics
                                  ▼
 n8n: Build MiniApp Data (єдине JS-обчислення для Owner View і чату) · Build Weekly Render Data/HTML · Xlsx: Build Rows · WR: Render Report
```

**Інваріант єдиного обчислення (TECH_SPEC §2.1):** показник рахується в одному місці. Рівень проєкту — `archi_recalc()`; сигнали ETC/узгодженість/акти/виконання плану — SQL-в'ю; портфель і решта кольорів Owner View — `Build MiniApp Data`; Weekly Render, чат ПМа, xlsx — **лише відображення**. Відомі порушення: `AN: Attach Block` (CTO #1), колір стадійного блоку в браузері (`stageBlock`).

**Тригери (Факт):** `archi_recalc_time` (time_log), `archi_recalc_money`, `archi_recalc_wr` (wr_weekly_snapshots), `archi_recalc_schedule` (payment_schedule), `archi_recalc_plan` (project_metrics I/U) → `archi_recalc_trg()` → `archi_recalc()`. Workflow `archi_recalc` не викликає.

**Таблиці ARCHI:** `project_metrics` (план + розрахункові поля; ~43+ колонок), `wr_weekly_snapshots` (колонки **кирилицею**: `готовність_pct`, `залишок_прогноз_по_стадіях`, `залишок_прогноз_год`, `дедлайн_прогноз_по_стадіях`, `ймовірність_акту`, `ймовірність_документації`, `блокер`, `розбіжність_готовності`, `plans_next_week`, `problems`, `help_needed`, `pm_comment`, `final_message`, `item_statuses`), `wr_plan_items` (`origin_week`, `carry_count`, статуси `pending/done/not_done/no_answer`), `archi_wr_inbox` (черга; **RLS увімкнено**), `archi_bot_mode_state` (режим чату), `archi_thresholds`, `payment_schedule`, `rates`, `time_log`, `money_log`, `meeting_log`, `kp_log`, `n8n_chat_histories`. У базі ще ~25 чужих/архівних таблиць (`_bak_*`, `jarvis_*`, `shift_*`, `bot_*`) — не чіпати. RLS **вимкнено** на 28 таблицях схеми `public` (SECURITY п. 5–6; рішення власника).

**Типи договорів:** `contract_type='stages'` (МБР/ЕП/П/Р) і `'visit'` (АН «оплата за виїзд», проєкти `*-АН`; виключені з портфеля, Weekly Render, статусу звітів; блок «Авторський нагляд» будує `AN: Split Stage Rows → AN: Attach Block → AN: Patch HTML`).

**`archi_thresholds` (31 ключ; значення БД = резервні значення в коді; читач):**

| Ключ | Значення | Читає |
|---|---|---|
| `rent_drop_pp` / `rent_drop_pp_red` | 5 / 10 п.п. | `Build MiniApp Data`, `AN: Attach Block` |
| `profit_yellow_pct` / `profit_red_pct` | 5 / 10 % | `Build MiniApp Data` |
| `cpi_yellow` / `cpi_red` | 0,95 / 0,85 | `Build MiniApp Data`, `AN: Attach Block` |
| `etc_yellow` / `etc_red` | 0,05 / 0,10 (від BAC) | `Build MiniApp Data`, SQL `archi_vac_signal` |
| `idx_yellow` / `idx_red` | 0,9 / 0,7 | `Build MiniApp Data`, SQL `archi_idx_signal` |
| `unpaid_yellow` / `unpaid_red` | 0,10 / 0,25 (частка контракту) | `Build MiniApp Data`, `AN: Attach Block` |
| `slip_red_days`, `block_red_days` | 14, 14 | `Build MiniApp Data` |
| `doc_prob_yellow` / `doc_prob_red` | 6 / 3 | `Build MiniApp Data` |
| `opt_etc_drop`, `opt_ready_max` | 0,40, 50 | `Build MiniApp Data` (S-05) |
| `plan_exec_yellow` / `plan_exec_red` | 70 / 50 (%) | SQL `archi_plan_execution`, `Build MiniApp Data` |
| `readiness_gap_pp` | 20 п.п. | `WR: Parse Agent Output`, `WR: Fetch Project Metrics Static` (S-12) |
| `wr_ready_gap_pp` | 10 п.п. | SQL `archi_ready_gap_signal` (E-04) |
| `plan_year_projects` 70; `plan_year_hours` 84 000; `plan_year_contract` 47 250 000; `plan_year_profit` 9 450 000; `plan_year_rent_pct` 25; `plan_avg_project_hours` 1 200 | план бюро | `Build MiniApp Data` (портфель) |
| `plan_fx_uah_usd` 45, `demo_asof` 20261021, `profit_yellow_share` 0,8 | — | **ніхто не читає** (CTO #6) |

---

## 6. Карта workflow `CKwCsGIwyw9feCY5` (179 вузлів)

Групи за префіксом: `WR:` 62, без префікса 47, `Import:` 16, `Doc Intake:` 16, `Meeting:` 14, `K:` 7, `KP Log:` 5, `Xlsx:` 4, `M:` 3, `AN:` 3, `WR-Render:` 2.

### 6.1 Telegram Trigger (лише `message`) → 4 паралельні гілки на кожне повідомлення
**Увага:** Telegram Trigger приймає повідомлення від **будь-кого** (`additionalFields: {}`); порядок виконання сестринських гілок залежить від координат вузлів на полотні (`executionOrder v1`).
1. **Головна:** `WR: Ensure Mode Table` → `WR: Read Mode` (`archi_bot_mode_state` по `chat.id`) → `WR: Determine Route` (`is_wr_flow` = команда WR **або** активний режим `weekly_report / weekly_reference / import_log / meeting_log / koshtorys_preview` і не точна команда Owner View/Weekly Render) → `WR: Is WR Flow?`
   - **true:** `WR: Is Audio or Photo?` (голос → transcribe; фото → gpt-4o; документ → `WR: Detect Doc Type` → PDF/TXT; текст) → `WR: Hard Logic Engine` (детермінований роутер, `execution_mode`) → `WR: Route` (Switch, **18 виходів**):

| Вихід | `execution_mode` | Далі |
|---|---|---|
| 0 | `clear_context` | `WR: Reset Mode` → меню |
| 1 | `need_project` | `WR: Send Need Project` |
| 2 | `set_project` | `WR: Write Project Mode` → бриф + план минулого тижня (`WR: Send Project Confirmation`) |
| 3 | `status` | `WR: Fetch Report Status` («📋 Статус звітів») |
| 4 | `set_reference_mode` | `WR: Write Reference Mode` («📖 Довідник») |
| 5 | `process_data`, `show_draft`, `generate_final`, `send_inbox` | **звіт ПМа** (розділ 7) |
| 6, 7 | `set_import_project`; `process_import_data` / `show_import_draft` / `generate_import_final` | Import («⏱ Години і гроші» → `time_log`/`money_log`) |
| 8, 9 | `set_meeting_project`; `process_meeting_transcript` / `show_meeting_draft` / `generate_meeting_final` | Meeting («🤝 Зустріч» → `meeting_log`) |
| 10–12 | `reset_wr_draft`, `reset_import_draft`, `reset_meeting_draft` | `WR: Reset Draft` (чистить пам'ять **і** чергу) / Import / Meeting |
| 13, 14, 15 | `koshtorys_preview`, `koshtorys_commit`, `koshtorys_hint`/`koshtorys_forbidden` | K6sm («📐 Кошторис»; allowlist) |
| 16 | `pick_project` | `M: Fetch Project List → M: Build Project Keyboard → M: Send Project Picker` (HTTP напряму в Bot API, токен у URL) |
| 17 | `buffer_data` | `WR: Inbox Add` → `WR: Send Inbox Ack` («📥 Прийнято · У черзі: N») |

   - **false:** `Is Status Command?` → `Is Weekly Render Request?` → `Is Owner View Request?` (`/project|/owner_view` або точна фраза «огляд/меню/owner view/owner») → інакше **чат**: `Fetch KP Log Sum (Chat)` → `Fetch Project Metrics (Chat)` → `Build MiniApp Data` → `Is Chat Request?` (`$('Telegram Trigger').isExecuted` — розрізняє Telegram і вебхук; **не «завжди true»**) → `Fetch Meeting Log (Chat)` → `Attach Meeting Log` → `Build Request Body` (детектор Q1–Q10, дані пораховані кодом, LLM лише формулює) → `Call Anthropic` → `Sanitize Reply` (читає `content[0].text`; Markdown→HTML; теги b/i/u/s/code; обрізка 3900) → `Send Reply`.
2. **Doc Intake — команда:** `^договір\s+<id>$` → режим `document_intake`.
3. **Doc Intake — вміст:** режим `document_intake` + фото/документ/посилання Drive → RC7H або запис URL → скидання режиму (читає `$('WR: Read Mode')` з гілки 1 — CTO #5).
4. **KP Log:** `^кп[:\s]+(надіслано\s+)?(\d+)$` → `kp_log` → місячна сума. `Is Parallel Cmd?`: **вихід 0 навмисно порожній** — глушить чат-відповідь на «КП: N», «договір X», Doc Intake (дефект D6, виправлено).

### 6.2 Меню (постійна клавіатура, 13 вузлів із однаковою розкладкою)
«📝 Тижневий звіт», «⏱ Години і гроші», «🤝 Зустріч», «📐 Кошторис», «📋 Статус звітів», «📊 Owner View», «📖 Довідник», «❓ Питання», «📄 Договір», «📅 Щотижневий рендер». Клавіатура звіту: «📤 Відправити», «📄 Чернетка», «✅ Фінал», «🆕 Новий», «❌ Скасувати» (+ «⬅️ Назад» у брифі). Зміна клавіатури = правка кількох вузлів (дублікати відомі).

### 6.3 Інші тригери
- `MiniApp Page Webhook` → `Build MiniApp HTML` → Respond; `AN: Patch HTML` вставляє блок АН за якорями в HTML (`throw` якщо якорі зникли — крихко).
- `MiniApp Data Webhook` → `Validate InitData` → `Is Valid InitData` → `Fetch KP Log Sum (MiniApp)` → `Fetch Project Metrics (MiniApp)` → `Build MiniApp Data` → `AN: Split Stage Rows` → `AN: Attach Block` → Respond.
- `Weekly Render Page/Data Webhook` → `WR-Render: Validate InitData` → `Fetch All Project Metrics` → `Fetch Weekly Snapshots For Grid` → `Build Weekly Render Data` (без грошей) → `Build Weekly Render HTML`.
- `Xlsx Export Webhook` → `Xlsx: Validate InitData` → `Fetch All Weekly Snapshots` → `Xlsx: Build Rows` → `Xlsx: Convert To File`.
- `WR: Schedule Reminder (Fri 10:00)` — `cron` без вихідних (D1).

### 6.4 Ключові Code-вузли
| Вузол | Розмір | Що робить |
|---|---|---|
| `Build MiniApp Data` | ~33 КБ | сигнали, класи кольору, групи, портфельний `pfc` (План/Факт/Прогноз + колір прогнозу року `fcSig`), `views`, `attention`, `rules`; **`TODAY` за Києвом**; ETC-сигнал читає з SQL |
| `Build MiniApp HTML` | ~26 КБ | увесь Mini App (HTML у template literal: не вживати `` ` `` і `${`) |
| `Build Request Body` | ~37 КБ | системний промпт чату, детектор Q1–Q10, глосарій |
| `WR: Build WR Prompt` | ~25 КБ | промпт WR-агента; payload залежить від режиму (див. п. 7) |
| `WR: Parse Agent Output` | ~21 КБ | **центр логіки звіту** (розділ 7) |
| `WR: Render Report` | ~9 КБ | складає звіт пп. 1–12 з полів (LLM звіт **не** складає) |
| `WR: Hard Logic Engine` | ~6 КБ | роутер команд і режимів |
| `Sanitize Reply` | — | екранування `&<>`, баланс тегів, обрізка 3900 |

---

## 7. Тижневий звіт ПМа — як це працює (найскладніша частина)

**Користувацький флоу:** «📝 Тижневий звіт» → вибір проєкту (`pick_project`) → бриф (перелік питань + незакритий план минулого тижня) → ПМ пише довільні повідомлення → кожне **лише копиться** в `archi_wr_inbox` («📥 Прийнято · У черзі: N») → «📤 Відправити» → Archi опрацьовує **всю чергу одним запитом** і показує чернетку з питаннями → ПМ дописує → … → «✅ Фінал». «📄 Чернетка» — лише показ. «🆕 Новий» — чистить пам'ять агента й чергу, лишає клавіатуру звіту. «Відповіді нема» — допустима відповідь на кожне питання.

**Черга (§93):** `buffer_data` → `WR: Inbox Add` (INSERT у `archi_wr_inbox`) → ack. `send_inbox`/`generate_final` → `WR: Fetch Payment Schedule` → `WR: Ensure Plan Table` → `WR: Fetch This Week Plan` → `WR: Fetch Project Metrics Static` → `WR: Fetch Money Log Acts` → `WR: Fetch Inbox` (повертає `inbox_text`, `inbox_count`, `inbox_max_id`, `mem_real`, `mem_text`) → `WR: Final Has Data?` (`generate_final` і `inbox_count=0` і `mem_real=0` → `WR: Send Final No Data`, LLM не викликається) → `WR: Build WR Prompt` → `WR: Agent` → `WR: Parse Agent Output` → **розгалужується на два сестринські вузли**: `WR: Is Final?` і `WR: Inbox Consume`. `WR: Is Final?` true → паралельно `WR: Merge Carryover → WR: Split New Plan Items → WR: Save Next Week Plan` (план наступного тижня) і `WR: Save Weekly Snapshot` (UPSERT по `project_id + week_start`, `$now.startOf('week')` за Києвом; `onError continueErrorOutput`, `retryOnFail`); false → одразу `WR: Fetch Report Today`. Далі `WR: Fetch Report Today → WR: Render Report → WR: Is Final (Render)?` → `WR: Send Final Report` (→ `WR: Clear Draft After Final`) або `WR: Send Draft Reply`. `WR: Inbox Consume` (`DELETE … id <= inbox_max_id`) стоїть **нижче** `WR: Is Final?` на полотні (Y 1440 проти 1280), тож за `executionOrder v1` виконується **після** повної гілки `Is Final?` — це безпечний порядок (збій гілки = черга не видалена = повторна обробка), але він залежить від координат вузлів (той самий клас крихкості, що CTO #5): **не рухати ці вузли по Y**.

**Що робить `WR: Parse Agent Output` (по порядку):**
1. Розбір JSON від LLM (`ask`, `stage_readiness`, `etc_forecast_hours_stage`, `deadline_forecast_stage`, `doc_probability`, `act_probability`, `plans_next_week`, `item_statuses`, `problems_text`, `help_text`, `pm_comment_text`, `blocker_types/since/need`, `no_answer`, `readiness_gap_confirmed/note`).
2. **Варіант Б (п. 9):** `srcText = mem_text + inbox_text` (усі повідомлення ПМа з пам'яті сесії + поточна черга); `hasNum` (числа, окремо від дат), `hasDate` (дд.мм.рррр, рррр-мм-дд, «6 листопада»); готовність/ETC/дедлайн/документація/блокер, що LLM «витягнув», але яких немає в тексті — видаляються з виходу і йдуть у блок «⚠️ Не підтверджено вашим текстом». Слова «нема/нуль/завершено/без змін/за планом» → `wordsFor(стадія, regex)`: підтверджують лише в **тій самій частині речення**, де названо стадію (`clauses` = розбиття за `\n ; ! ? , .`). Блокер: «немає» — лише за словами про відсутність; блокер і його тип (`люди/гроші/замовник`) — лише за словами про зупинку/тип; дата блокера — з тексту. Імовірність акту — **авто** за Кошторисом, не від LLM (не перевіряється). Стадії поза договором (ETC_план 0) не шумлять у переліку.
3. Статуси пунктів минулого плану (`done/not_done/no_answer/pending`), перенос `not_done/no_answer` у новий план (`carry_count + 1`); план наступного тижня ділиться по `\n`, `;`, маркерах `1)`.
4. Стадії поза договором → готовність 100, ETC 0; стадія з готовністю 100% — завершена (ETC 0 автоматично, **дата не питається і не зберігається**).
5. **Гейт «Фінал» (код, не LLM):** `missing` — готовність, ETC, дата по кожній стадії (дата незавершеної стадії **не в минулому**: нова дата або «відповіді нема»), ймовірність документації, план наступного тижня, статус кожного `pending` пункту, блокер (є/немає, з якої дати). Прийнято = `generate_final && !missing && !gapOpen`.
6. S-12 «⚖️ Розбіжність готовності»: |оцінка ПМ − Витрачено/(Витрачено+ETC_прогноз)| ≥ 20 п.п. → питання; підтвердження — слова «підтверджую розбіжність» + причина.
7. Вихід: `tag` (`DRAFT`/`FINAL_REPORT`), `ask`, `pre_blocks`, `post_blocks`, `etc_total_forecast` (лише якщо дано всі 4 стадії), `stage_readiness`, `etc_forecast_stage`, `deadline_forecast_stage` (без завершених), `doc_probability`, `act_probability`, `blocker`, `readiness_gap`, `plan_prev`, `plan_next_items`, `item_statuses`, тексти.

**Знімок:** `wr_weekly_snapshots` → тригер `archi_recalc_wr` → `archi_recalc()` → `project_metrics` → `archi_report_today` → `WR: Render Report`.

**Форма звіту (пп. 1–12):** 1 Рентабельність (план → прогноз) · 2 ETC, год (ETC_план / ETC_факт / ETC_прогноз + Δ з кольором) · 3 Готовність · узгодженість (Витрачено; Готовність ПМа; За прогнозом; Ефективність годин; Ефективність виконання; МБР довідково) · 4–6 Стадія ЕП/П/Р · 7 Акт (дата · N/10; «Акти ÷ план на дату», «Виставлено ÷ освоєне», «Оплата ÷ акти») · 8 Документація · 9 Проблеми · 10 Допомога · 11 План на тиждень (🔴 перенесено ×N, «Виконання минулого плану X з M · P%») · 12 Коментар ПМ. Чернетка: значення, яких ще немає, — «⏳ після «Фінал»». Деталі й перевірка нумерації — `WEEKLY_REPORT_FORM.md`, `scripts/check_report_form.py`.

**Контрольний текст для live-тесту (DEMO-03)** — він же `FULL` у `tests/wr_parse_agent_output/run.js`:
```
МБР завершено
ЕП 95%, годин ще 13, дедлайн 06.11.2026
П 70%, годин ще 110, дедлайн 20.11.2026
Р 10%, годин ще 370, дедлайн 30.11.2026
Документація 8
Блокера немає
План: 1) закрити ЕП; 2) почати Р
```
Очікуване після «Відправити»: блоку «Не підтверджено» нема; готовність 100/95/70/10; ETC_прогноз разом 493 год; дедлайни ЕП 06.11, П 20.11, Р 30.11; документація 8/10; блокера нема; план: 2 перенесені + 2 нові. Після «Фінал»: знімок `wr_weekly_snapshots` збігається з текстом (так було: id 217, §108). **Прийнятий «Фінал» перезаписує знімок DEMO-03 за цей тиждень** — попередити власника.

---

## 8. Формули і кольори (конспект; канон — `docs/FORMULAS.md`)

**Рівень проєкту (`archi_recalc_stages`, Факт 25.10.2026):** лише `статус='confirmed'` у `time_log`/`money_log`; AC = Σ(години × ставка `rates.razom_grn_god` або `real_rate_team_hour`) + оплачені субпідрядники; `ETC_total` і `pct_complete` — лише якщо ПМ дав **усі 4 стадії**; стадія з планом 0 → готовність 100, ETC 0; `EV_контракт = contract × pct_complete` (Archi), `EV_classic = bac × pct_complete`, `cpi_classic_evm = EV_classic / AC`; `cost_final = AC + ETC_total × ставка + залишок субпідряду`; `profit_forecast = contract − cost_final`; прогнозу від ПМа нема → `NULL`, завжди 🔴 (план не підставляється).

**Сигнали (FORMULAS §3):** S-01 прогноз відсутній · S-02 рентабельність (прогноз < 0 або падіння ≥ 10/5 п.п. від плану) · S-03 прибуток (≥ 10/5% відносного відхилення) · S-04 ETC Δ від **BAC** (`archi_vac_signal`; Δ ≤ 0 → 🟢) · S-05 оптимістичний прогноз ПМа · S-06 не оплачено (> 25/10% контракту) · S-07 акти відстають · S-08 CPI (< 0,85 / 0,95) · S-09 терміни стадії (> 14 дн.) · S-10 документація (≤ 3 / ≤ 6) · S-11 ⛔ блокер (≥ 14 дн.; **дні — від сьогодні за Києвом**) · S-12 ⚖️ розбіжність готовності (20 п.п.) · S-13 ПМ просить допомоги · S-14 ПМ не подавав звіт · S-15 виконання плану тижня (< 50/70%).

**EVM-ланцюжок Weekly Render (E-01…E-07):** Витрачено = AC/BAC · Готовність ПМа = EV/BAC · За прогнозом = AC/EAC (EAC = AC + ETC_прогноз) · Ефективність годин = BAC/EAC · узгодженість = Готовність ПМа − За прогнозом (≥ 10 п.п. в обидва боки → 🔴, `wr_ready_gap_pp`) · «Акти ÷ план на дату» (за `payment_schedule`) · «Виставлено ÷ освоєне (WIP)» (**без кольору**) · «Оплата ÷ акти». Кольори індексів: жовтий < 0,9, червоний < 0,7. **Weekly Render без грошових сум** (п. 7).

**Портфель (`pfc`):** рядки Проєкти (Факт = проєкти з договором; Прогноз = Факт + КП/міс × 20%), Workload, не оплачено год, Прибуток, Рентабельність від контракту (від собівартості — лише в картках проєктів, §124–§125), далі внизу «КП, надіслано» і «Договори, підписано» (28.10.2026); колір «Прогноз» — лише шрифт (`pfc.fcSig`: `idx_*`, `profit_*`, `rent_drop_pp*`).

**Дві CPI на картці (0,91 і 1,17) і підпис «EV = контракт × готовність» під CPI 0,91, різні типи порогів прибутку й рентабельності, рядок «Факт» у «Гроші» — свідомо не латати до вкладки «EVM (класичний)»** (рішення власника 25.10, §101–§102).

---

## 9. Що зроблено 15.10 → 25.10.2026 (коротко; деталі — RELEASE_PLAN)

| Період | Зроблено | § |
|---|---|---|
| 15–16.10 | Owner View: план бюро, КП, таблиця портфеля, питання Q1–Q10 як кнопки; картка План\|Факт\|Прогноз; CPI за годинами; дві рентабельності; перший CTO Checkpoint | §43–§59 |
| 17–18.10 | АН-договори «оплата за виїзд»; демо-дані для 14 проєктів (88 знімків, 324 `time_log`, 75 `money_log`); Кошторис без АН; 18 демо-договорів на Drive; кнопка Weekly Render; мобільна верстка; дата оновлення даних (F-28); фікс маршруту ПМа; **єдина форма звіту скрізь** (R-01…R-06); контур «План тижня» PX-01; другий CTO | §60–§77 |
| 20–22.10 | Weekly Render: однакова форма пп. 1–12 по тижнях (`archi_snapshot_history`); ETC-трійка + Δ; EVM-ланцюжок; кольори відхилень; CPI прибрано; самоаудит (E1–E10) і рішення R1–R5; третій CTO | §78–§86 |
| 24.10 | S-04 на BAC і з SQL в Owner View; колір прогнозу року; replay на живих даних (`scripts/replay/`) | §87–§91 |
| 24–25.10 | **Черга ПМа**, «Фінал» без даних, дата в минулому, «Новий», розбиття плану, тест DEMO-03; рішення про дві методології | §92–§103 |
| 25.10 | **Варіант Б** (§104–§111) з live-тестами; план по рядках (§109); дубль «ПМ підтвердив» (§110); CTO Checkpoint 25.10 (P0 0 · P1 2 · P2 7) і виправлення #2–#4 (§112–§113); тести й дата за Києвом (§114); токен прибрано з HEAD; `CLAUDE.md` п. 9 | §104–§115 |

Усе перелічене — ✅ з перевіркою (SQL/execution/скрін власника) у RELEASE_PLAN; **виняток — дата за Києвом (`8a9fe9e5`), див. §1.6.**

---

## 10. Як перевіряти (інструменти)

| Що | Як |
|---|---|
| Логіка `WR: Parse Agent Output` | `node tests/wr_parse_agent_output/run.js` — 29 перевірок, код вузла береться з `workflows/DEMO_Archi_Agent_Core.json`; перевірено на мутаціях (прибрати привʼязку до стадії / перевірку блокера / перевірку дат → тест падає). Макет, не live. При зміні вузла — додати сценарій |
| Форма звіту | `python3 scripts/check_report_form.py` → «Розбіжностей: 0» (нумерація й підписи в `WR: Render Report` і `Build Weekly Render HTML`) |
| Weekly Render / Owner View на живих даних без Telegram | `scripts/replay/replay_weekly_render.js`, `replay_owner_view.js` (Chromium з підміною вебхука; вебхуки n8n з контейнера недоступні, підробити Ed25519 Telegram неможливо) — див. §88 |
| Дані проти незалежного обчислення | SQL «C-3» з `docs/CTO_CHECKPOINT_PROMPT.md` (AC, собівартість прогнозу) — розбіжність = P0 |
| Аудит коду проти документів | `docs/CTO_CHECKPOINT_PROMPT.md` (читання; щопонеділка / перед демо / після ≥ 3 публікацій) |
| Live-тест у Telegram | гайд ASD-STE100 власнику (текст, очікуваний результат, скрін), після — SQL по знімку/черзі. Власник тестує сам; Claude **не** може відкрити Mini App |
| Кеш Telegram WebView | після публікації просити повністю закрити Mini App (✕) і відкрити знову — інакше видно стару картку |

---

## 11. Розбіжності документів ↔ живий код (документи, що застаріли)

- `docs/TRANSITION_PROMPT_2026-10-15.md` (v1) — історія: кількість вузлів (167), `activeVersionId`, «Залишок» у деяких місцях, відсутні черга, варіант Б, EVM-вкладка, п. 8–9.
- `docs/ARCHI_TECH_SPEC_v3_0.md` §6 «Реєстр середовища» мав застарілий `ac85ca96-…` — **виправлено 25.10.2026** (тепер `8a9fe9e5…`); §4.2 (потік звіту) описує 6 розділів і не згадує чергу — канон тепер `WEEKLY_REPORT_FORM.md` і розділ 7 цього файлу.
- `README.md` — структура застаріла у кількох місцях (опис «Розділ 10»…); `activeVersionId` оновлюється з кожною зміною.
- `SECURITY.md` п. 1 переписано 25.10.2026 за фактом; п. 5–7 (RLS, allowlist чату) без змін.
- `docs/FORMULAS.md` — актуальний до S-11 (дата за Києвом, §114); якщо змінюєш формулу/поріг/підпис — оновити тим самим комітом.

---

## 12. Як технічно працювати

**n8n MCP (`OSBB_n8n`):**
- `update_workflow` має лише `setNodeParameter` (повна заміна значення: `/jsCode`, `/query`, `/text`) і `setWorkflowSettings`; patch-операції **немає**. Кожна правка Code-вузла = повний текст (Build MiniApp Data ≈ 33 КБ, Parse Agent Output ≈ 21 КБ). Готуй текст Python-ом із файла експорту (`assert old in s; s.replace(old, new, 1)`), `node --check`, передавай повністю.
- `versionName` ≤ 80 символів. Після `update_workflow` — `get_workflow_details` (результат іде у файл; `json.load(...)['workflow']`), порівняння з надісланим **побайтово** (`rstrip('\n')` — різниця лише в кінцевому переносі припустима), тоді `publish_workflow` з `versionId` чернетки.
- Дублі вузлів (6 клавіатур, 3 `Validate InitData`, 2 `Fetch Project Metrics`) — міняти **всі** копії.
- Вузол із `queryReplacement` вже є: `K: Save Mode`, `K: Reset Mode`, `WR: Fetch Payment Schedule`, `WR: Fetch Report Status`, `WR: Fetch Report Today`, `Doc Intake: Write Link URL`, `KP Log: Insert Row` — взірці для параметризації.
- Запити вузлів Postgres, що **починаються з `=`**, інтерполюють `{{ }}`; запити без `=` — звичайні. `n8n` попереджає, що `query` не підтримує вирази — це «pre-existing», не нова проблема.
- `test_workflow` виконує неспіновані вузли по-справжньому — не використовувати без пінування.
- Скрипти/копії вузлів тримай у scratchpad, але **між сесіями він не зберігається**: актуальний код — з живого n8n або `workflows/DEMO_Archi_Agent_Core.json`.

**Supabase MCP:**
- `execute_sql` — читання; запис може чекати підтвердження власника → він виконує в SQL Editor. Багатооператорний SQL інколи «cancelled» — один оператор або `DO $$ … $$`. `apply_migration` — для DDL (файл у `sql/`).
- `archi_thresholds.value` — numeric. Зміни `archi_recalc*`: `pg_get_functiondef` + `replace` + `EXECUTE`, тест з `RAISE EXCEPTION` для відкату.
- Не змінювати розрахункові поля `project_metrics` напряму — лише через вхідні таблиці й `archi_recalc`.

**Репозиторій:**
- Робоча гілка від `origin/main`; кожна зміна в n8n/Supabase → той самий PR: експорт `workflows/DEMO_Archi_Agent_Core.json` (повний live JSON, `versionId = activeVersionId`, `json.dumps(indent=2, ensure_ascii=False)+"\n"`, **токен → `<TELEGRAM_BOT_TOKEN>`**; перед комітом `grep -rE "[0-9]{8,}:AA[A-Za-z0-9_-]{30,}" --exclude-dir=.git .` → 0), README (рядок версії — переписувати блок, не `replace` ID), новий розділ RELEASE_PLAN (що зробив → результат → спосіб перевірки → checkpoint), за потреби TECH_SPEC/FORMULAS/SECURITY. Коміти й PR українською; GitHub лише через MCP `mcp__github__*`; кінець сесії — PR + merge у `main`. Не створювати PR без прохання власника (у цьому проєкті власник просить; перевіряти).
- Атрибуція: коміт/PR закінчуються рядками з системного нагадування сесії; ідентифікатор моделі в артефакти репозиторію **не писати**.

**Робота з власником:** перед кроком, що спалює > 10% ліміту — спитати. Один уточнювальний запит максимум. Після будь-якої правки — гайд для Telegram (ASD-STE100) і чекання скрінів; скріни аналізувати по всіх полях, не вибірково. Числа з макета не видавати за живі.

---

## 13. Уроки (накопичені)

1. Перевіряти твердження зовнішніх аналізів кодом: «`Is Chat Request?` завжди true» і «`Is Parallel Cmd?` — бита гілка» виявились хибними.
2. Експорт workflow без заміни токена кладе чинний токен у публічний репозиторій (так було 17–25.10.2026) — після кожного експорту `grep`.
3. Механічна заміна `OLD → NEW` ID у README/TECH_SPEC псує мітки версій — переписувати блок цілком; `TECH_SPEC` §6 так і лишилась застарілою.
4. Слова-підтвердження («немає», «завершено») діють лише в частині речення з назвою стадії, інакше «Блокера немає» підтверджує «ETC МБР = 0».
5. LLM вигадує «блокера немає», плановий дедлайн, «МБР 100%», готовність Р 0% — перевіряти не лише числа, а й порожні значення.
6. Дані, які бачить користувач, нормалізувати в SQL запиту (один шар для Owner View, чату, Weekly Render), а не в JS кожного вузла (так виправлено план по рядках і дубль «ПМ підтвердив»).
7. Кеш Telegram WebView показує стару картку після публікації — просити повністю закрити й відкрити Mini App.
8. `$now` у n8n залежить від timezone workflow — задано `Europe/Kyiv`.
9. Тести на макеті треба «ламати» мутаціями коду — інакше не видно, що вони щось ловлять.
10. Не плутати «перевірено в коді/на макеті» і «перевірено наживо»: у звіті власнику це різні статуси.
11. Копії дублів (клавіатури, `Validate InitData`) — джерело розсинхрону; міняти всі.
12. (з v1) У Mini App HTML не вживати `` ` `` і `${`; частина рядків записана як `\uXXXX` — подвійне екранування `\\u…` у JSON-параметрі нормальне.
13. (з v1) Не вгадувати сенс рукописних позначок власника на скрінах.
14. Паралельні запуски на кожне повідомлення ламали звіт (гонки) — рішення «чергa + обробка по кнопці» (варіант А), а не блокування.
15. Зовнішні аналізи (нейронки) корисні як чек-лист ризиків (SQL-інʼєкції, моноліт, тести), але частину тверджень треба спростовувати кодом.

---

## 14. Заборони

❌ Починати зміни в n8n/Supabase до прочитання `CLAUDE.md`, цього файлу, RELEASE_PLAN, `SECURITY.md`.
❌ Вмикати RLS на існуючих таблицях, ротувати токен, обмежувати доступ до бота — без рішення власника.
❌ Комітити експорт workflow з живим токеном; пропускати `grep` токена.
❌ Переписувати документи «під код» без власника (розбіжність — знахідка); залишати репозиторій позаду живого стану.
❌ Підставляти план або «правдоподібний» варіант замість відповіді ПМа (п. 9); видавати відсутність даних за норму.
❌ Додавати гроші у Weekly Render; змінювати його вигляд без прямого запиту; вживати «Залишок»; верстати не стовпчиком.
❌ Латати змішані показники двох методологій (п. 8); додавати нові патч-вузли `html.replace` (`AN: Patch HTML` — відомий борг).
❌ Обчислювати показник поза двома місцями обчислення (TECH_SPEC §2.1); повертати лінійну екстраполяцію темпу.
❌ Чіпати `I3K5tBj0FWF1dbWb` (Representative Bot); видаляти/змінювати тестові дані без згоди власника (знімок DEMO-03 id 217 — тестовий).
❌ Видавати числа з макета за живі; писати «зроблено» про те, чого не бачив на екрані.
❌ Запускати цикли, що спалюють > 10% ліміту сесії, без питання «продовжувати?».

---

## 15. Контекст проєкту (коротко)

ARCHI — Telegram-бот і Mini App для власника архітектурного бюро (Андрій, COO): Owner View (гроші), Weekly Render (відхилення від плану без грошей), чат ПМа з тижневим звітом. n8n + Supabase; код і SQL рахують, LLM лише розбирає текст ПМа і формулює питання. Дві методології: Archi (основна) і класичний EVM (окрема вкладка, не реалізовано). Продукт будується повним, без обрізаних рішень; кожна зміна в n8n/Supabase супроводжується оновленням репозиторію тим же PR. Демо-середовище: 14 проєктів (DEMO-01…10, 22-24, 24-11, 24-37, 24-52) + 4 договори АН; «станом на» — дата оновлення даних, не вигадана.

## Історія редакцій
- v1 (15.10.2026): `TRANSITION_PROMPT_2026-10-15.md` (167 вузлів, `ac85ca96`).
- v2 (25.10.2026, перша редакція): короткий — визнано недостатнім власником.
- **v3 / ред. 2 (25.10.2026): цей файл** — повний; охоплює 15.10–25.10 (черга ПМа, варіант Б, EVM-кольори, CTO 22/25.10, тести, дата за Києвом, інцидент токена).
