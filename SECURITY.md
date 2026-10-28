# Відомі проблеми безпеки — ARCHI

Факти, перевірені прямо в коді 13.09.2026. Не пом'якшено, не приховано.

## 1. 🔴 Telegram bot token у коді, репозиторій публічний

**Стан на 25.10.2026 (перевірено по живому workflow `cc94785c`, CTO checkpoint 25.10.2026, #4):**
- У живому n8n токен бота лежить літералом в **одному** вузлі — `M: Send Project Picker` (`httpRequest` на Telegram Bot API; URL має вигляд `.../bot<TOKEN>/sendMessage`, n8n-нода `telegram` не приймає динамічну клавіатуру цілим виразом).
- Три вузли `Validate InitData`, `WR-Render: Validate InitData`, `Xlsx: Validate InitData` токена **не мають**: підпис Telegram Mini App `initData` перевіряється публічним ключем Telegram (Ed25519, `crypto.verify`), у коді лише номер бота `BOT_ID` (не секрет). Це змінює історичний опис нижче («у ТРЬОХ нодах») — токен у цих вузлах більше не потрібен.
- Файл `workflows/DEMO_Archi_Agent_Core.json` у репозиторії **має містити заглушку** `<TELEGRAM_BOT_TOKEN>`, а не живий токен. **Правило експорту:** після `get_workflow_details` і до коміту замінити літерал токена на `<TELEGRAM_BOT_TOKEN>` (у вузлі `M: Send Project Picker` і в копії `activeVersion`), потім перевірити: `grep -E "[0-9]{8,}:AA[A-Za-z0-9_-]{30,}"` по репозиторію має повернути 0 рядків.

**Інцидент 17–25.10.2026 (Факт, перевірено `git log -S`):** при експортах workflow починаючи з коміту `c8a0f2a` (17.10.2026) і далі (`456c8f8` 18.10.2026 та наступні) у репозиторій потрапив **чинний** токен (не недійсний, як у запису 09.10.2026) — у двох місцях `workflows/DEMO_Archi_Agent_Core.json` (вузол і копія `activeVersion`). Заглушку, встановлену 09.10.2026, при експорті не відновлювали. Цим комітом токен із HEAD прибрано (заглушка), **але він лишається в публічній git-історії** (коміти з 17.10.2026). Чинний токен слід вважати скомпрометованим. Ротація (BotFather → Revoke → новий токен у `M: Send Project Picker`) — **рішення власника**; без нього токен не змінювався. [Припущення] GitHub secret-scanning міг вже відреагувати — потребує перевірки в налаштуваннях репозиторію.

**Рішення власника (13.09.2026, повторно підтверджено):** попередній токен НЕ ротувався («ризик постійного витоку прийнятий назавжди»). Це рішення стосувалось токена, що був тоді в коді. 09.10.2026 цей літерал виявився недійсним (Telegram 401) і замінений чинним токеном власника; відтоді діє політика «у репозиторії — заглушка». Чи поширюється «не ротувати» на чинний токен після інциденту 17–25.10 — **питання власнику** (CLAUDE.md «Заборонено» забороняє ротацію без його рішення).

Історичний запис (13.09–04.10.2026): старий токен `8813476306:AAG…` (замасковано; недійсний з 09.10.2026) лежав літералом у `Validate InitData`, `WR-Render: Validate InitData` і `M: Send Project Picker`. Рішення власника 13.09.2026 — «запушити як є в публічний репозиторій, ризик прийнято свідомо».

## 2. 🔴 Weekly Render Data Webhook без авторизації (регресія)

**Факт:** `Weekly Render Data Webhook` (`demo-archi-weekly-render-data`)
підключений напряму до `Fetch All Project Metrics`, минаючи ноди
`WR-Render: Validate InitData` / `WR-Render: Is Valid InitData` — вони є у
workflow, але нічого на них не веде (мертві, orphaned). Будь-хто, хто знає
URL, отримує дані по всіх 10 проєктах без Telegram-авторизації.

Оригінальний `MiniApp Data Webhook` (owner view) підключений правильно —
перевірено окремо, там `Validate InitData → Is Valid InitData → Read DEMO
Flat` в одному ланцюгу.

**Статус: ВИПРАВЛЕНО 13.09.2026.** У живому workflow видалено пряме
з'єднання `Weekly Render Data Webhook → Fetch All Project Metrics` і
підключено через `WR-Render: Validate InitData → Is Valid InitData`,
так само як в оригінальному `MiniApp Data Webhook`. Опубліковано
(`activeVersionId eeba13e1-5e89-43d4-b3a6-0b1b38b80d26`).

Перевірено двома реальними виконаннями workflow (не curl — вихідний
egress з цієї сесії заблокований проксі на `osbbcopilot.app.n8n.cloud`,
тест зроблено через n8n execution API):
- Execution `5512`, запит без `initData` → `WR-Render: Validate InitData`
  повернув `{"valid":false,"reason":"no_init_data"}` →
  `lastNodeExecuted: "Respond Weekly Render Unauthorized"`. Дані НЕ
  віддані.
- Execution `5513`, запит з коректно підписаним `initData` (HMAC за тим
  самим алгоритмом, що в коді ноди) → `{"valid":true,"hashValid":true,
  "fresh":true}` → дійшло до `Fetch All Project Metrics` →
  `Respond Weekly Render Data` з повними даними по всіх 10 проєктах.

Обидва тести пройдені.

## 3. Google Sheets credential, Postgres credential

Використовуються через n8n credential-посилання (id `ijBsXae1VQfiWISu`,
`9RgEysuE2hzWIIQq`) — самі секрети НЕ потрапляють в JSON-export, тільки
id/назва credential. Це безпечно для git.

## 4. Anthropic API

Викликається через `predefinedCredentialType` (credential id
`U5Ts0Bmqulc3foVf`) — так само безпечно, ключ не в JSON.

## 5. 🔴 Supabase RLS вимкнений на ключових таблицях Archi (нова знахідка, 26.09.2026)

**Факт, перевірено `list_tables` на проекті `bxawceksdkqlbkdgjvyz`:** Row
Level Security ВИМКНЕНИЙ на таблицях, які Archi читає й пише щодня:
`project_metrics`, `wr_weekly_snapshots`, `wr_plan_items`,
`archi_bot_mode_state`, `time_log`, `money_log`, `rates`, `meeting_log`
(і ще 18 інших таблиць проекту, не всі стосуються Archi). Це означає:
anon-ключ Supabase (клієнтський, публічний за дизайном Supabase) дає
ПОВНИЙ доступ на читання й запис до цих таблиць будь-кому, хто його
знає — по всіх 10 демо-проектах.

Для порівняння: нові таблиці цієї сесії (`archi_thresholds`,
`payment_schedule`) RLS увімкнений одразу при створенні — отже
проблема стосується тільки таблиць, створених до 25.09.2026.

**Статус: НЕ ВИПРАВЛЕНО.** Умисно — вмикати RLS без підготовлених
policies заблокує весь легітимний доступ теж (n8n-воркфлоу
використовують service-role чи прямий Postgres-конектор, не anon-ключ,
тому мали б не постраждати — але це припущення, не перевірено).
Потрібне явне рішення власника: чи приймати цей ризик так само свідомо,
як ризик з токеном бота (п.1), чи готувати policies зараз.

Ремедіація (НЕ застосовувати без підготовлених policies):

```sql
ALTER TABLE "public"."project_metrics" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."wr_weekly_snapshots" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."wr_plan_items" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."archi_bot_mode_state" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."time_log" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."money_log" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."rates" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."meeting_log" ENABLE ROW LEVEL SECURITY;
```

## 6. 🔴 Нова таблиця `kp_log` (04.10.2026) теж без RLS — той самий клас проблеми, не окрема

**Факт:** таблиця `kp_log` (лічильник комерційних пропозицій, Розділ 9.2
RELEASE_PLAN) створена 04.10.2026 БЕЗ RLS — перевірено прямим SQL
(`pg_class.relrowsecurity = false`). Це повторення проблеми п.5 на новій
таблиці, не нова категорія ризику: будь-хто з anon-ключем Supabase може
читати й писати в `kp_log`.

**Статус: НЕ ВИПРАВЛЕНО.** Умисно, з тієї ж причини, що й п.5 — чекає
того самого рішення власника про RLS-policies для Archi в цілому, не
точкового фіксу однієї таблиці.

Ремедіація (НЕ застосовувати без підготовлених policies, те саме
застереження, що й п.5):

```sql
ALTER TABLE "public"."kp_log" ENABLE ROW LEVEL SECURITY;
```

## 7. 🔴 Бот відкритий для будь-якого користувача Telegram (знайдено 09.10.2026, звірено читанням коду `bd4be4da`)

**Факт:** `Telegram Trigger` приймає `message` від будь-кого (`additionalFields: {}`, без `user_ids`/`chat_ids`).
Перевірка відправника (`ALLOWED = ['304884647']`) є лише в `WR: Hard Logic Engine` для команди «кошторис…»
і в трьох `Validate InitData` для Mini App/рендеру/xlsx. Шлях чату `Telegram Trigger → … → Build Request Body →
Call Anthropic → Send Reply` перевірки відправника не має (перевірено обходом графа з'єднань). Отже
будь-хто, хто знайде `@archi_demo_bot`, може: отримати зведення по портфелю з грошима (чат-агент),
вибрати проєкт і писати звіти/імпорт годин і грошей (`WR/Import/Meeting`), писати в `kp_log`, завантажувати
документи (`Doc Intake`).

**Посилюючий фактор:** у `Import: Insert Time Rows` / `Meeting: Insert Rows` поля `Дата`, `Стадія`, `Години`,
`Статус` вставляються в SQL без екранування (екрануються лише `ProjectID`, `Виконавець`, `Завдання`), а
`cleanTimeRows` не перевіряє формат дати/годин. Значення проходять через LLM з тексту користувача.

**Оновлення 27.10.2026 (щодо «посилюючого фактора»):** вузли `Import: Insert Time Rows`, `Import: Insert Money Rows`, `Meeting: Insert Rows` і `WR: Inbox Add` переведено на параметризований SQL (`$1…$n`, `queryReplacement`, явні `::text`/`::date`/`::numeric`; RELEASE_PLAN §116). Значення з тексту користувача більше не вставляються в SQL рядком у цих 4 вузлах. **Оновлення 28.10.2026 (блок A, RELEASE_PLAN §118):** так само параметризовано `WR: Save Weekly Snapshot` і `WR: Save Next Week Plan` — останні вузли, куди йшов вільний текст ПМа (`problems`, `help_needed`, `pm_comment`, `plans_next_week`, `item_text`, JSON блокера). Вільний текст користувача в інтерпольованому SQL: 0 вузлів. **Не виправлено:** 21 вузол Postgres з `'{{ … }}'` у запиті інтерполює лише `chat.id` і `project_id` (регулярки без лапок; шлях запису `project_id` в обхід регулярок не шукали); сам відкритий вхід бота (нижче) не змінювався. Окремо: вихід помилки `WR: Save Weekly Snapshot` (`continueErrorOutput`) нікуди не підключений — збій запису знімка не видно ні в чаті, ні в журналі.

**Статус: НЕ ВИПРАВЛЕНО. Потрібне рішення власника:** хто має право писати боту (лише власник чи також ПМи;
список Telegram-ID і де він зберігається). Це доступ, не технічний борг для автоматичного фіксу.

## 7. Нове SQL-вʼю `archi_report_today` (18.10.2026) — без RLS, як і таблиця-джерело

Вʼю `public.archi_report_today` (похідні показники з `project_metrics`) створене 18.10.2026 без обмеження доступу: так само, як
`project_metrics` (див. п. 5, RLS вимкнений). Нових даних воно не відкриває (лише обчислення над тим, що вже читається ключем
сервісу), але додає ще один обʼєкт у тому ж класі ризику. **Статус: НЕ ВИПРАВЛЕНО — частина рішення власника про RLS у цілому** (не вмикати самостійно).

## 8. Нове SQL-вʼю `archi_plan_execution` (18.10.2026) — без RLS

Вʼю `public.archi_plan_execution` (PX-01: підрахунок статусів `wr_plan_items`) створене без обмеження доступу, як і таблиця-джерело (§5, §7). Рішення про RLS — власника; самостійно не вмикати. Нові колонки `wr_plan_items.origin_week`, `carry_count` — без RLS з тієї ж причини.

## 9. Нове SQL-вʼю `archi_snapshot_history` (з 20.10.2026 також `etc_gap_*` і функція `archi_etc_gap_signal`) і функція `archi_snapshot_metrics` (20.10.2026) — без RLS

Вʼю читає `wr_weekly_snapshots`, `project_metrics`, `time_log`, `money_log`, `rates` (усі без RLS, див. §5). Нових таблиць і колонок немає. Рішення про RLS — власника; самостійно не вмикати.

## 10. Нові SQL-функції `archi_snapshot_evm`, `archi_idx_signal`, `archi_ready_gap_signal` і нові колонки вʼю `archi_report_today` / `archi_snapshot_history` (21.10.2026) — без RLS

Нових таблиць немає; джерела (`wr_weekly_snapshots`, `time_log`, `money_log`, `project_metrics`) — без RLS, див. §5. Рішення про RLS — власника. Середовище сесії скасовує міграції з `DROP VIEW/FUNCTION` — такі зміни виконує власник у Supabase SQL Editor.

## 11. Нова таблиця `archi_wr_inbox` (25.10.2026) — RLS увімкнено при створенні

Черга повідомлень ПМа до «Відправити» (текст звіту, розшифровки голосу, опис фото/документів). RLS **увімкнено** одразу (як `payment_schedule`), політик немає: n8n пише ролью `postgres` (власник таблиці, RLS обходить), анонімний ключ API доступу не має. Існуючі таблиці без RLS (§5) не змінювались. Запити n8n підставляли текст ПМа в SQL з екрануванням `'` → `''`; з 27.10.2026 вузол запису в чергу (`WR: Inbox Add`) параметризований (§116). Інші вузли, що працюють з чергою (`WR: Fetch Inbox`, `WR: Inbox Consume`), досі інтерполюють `chat.id` і `project_id` у SQL через `'{{ … }}'`; походження `project_id` (чи може він прийти з вільного тексту) і придатність до ін'єкції не перевірялися — відкрито.

