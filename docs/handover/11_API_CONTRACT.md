# ARCHI — API-контракт
Версія 1 · 05.11.2026. Джерело: експорт core workflow `a4c89c3c` (вузли webhook, `Validate InitData`, `Respond …`, `Build MiniApp Data`, `Build Weekly Render Data`, `Xlsx: Build Rows`). Машинний опис — `docs/handover/openapi.yaml` (OpenAPI 3.0). Усе нижче **Факт за кодом**, окрім позначеного «не перевірено»; зразків живих відповідей немає (запит потребує підписаного `initData` Telegram). Форма відповіді береться з коду, перелік полів проєкту — з об'єкта в `Build MiniApp Data`.

## 1. Огляд
| Ендпоінт | Метод | Відповідь | Авторизація | Вузол |
|---|---|---|---|---|
| `/webhook/demo-archi-owner-view` | GET | `200 text/html` (сторінка Owner View) | немає | `MiniApp Page Webhook` |
| `/webhook/demo-archi-owner-view-data` | GET | `200 application/json` або `401` | `initData` + доступ до компанії | `MiniApp Data Webhook` |
| `/webhook/demo-archi-weekly-render` | GET | `200 text/html` (сторінка Weekly Render) | немає | `Weekly Render Page Webhook` |
| `/webhook/demo-archi-weekly-render-data` | GET | `200 application/json` або `401` | `initData` + доступ | `Weekly Render Data Webhook` |
| `/webhook/demo-archi-export` | GET | `200` xlsx або `401` | `initData` + доступ | `Xlsx Export Webhook` |
Базовий URL: `https://osbbcopilot.app.n8n.cloud` (n8n Cloud). Версіонування API немає. Rate limiting у коді немає. Ідемпотентність: усі ендпоінти лише читають, повтор безпечний.

## 2. Авторизація
1. Клієнт (Telegram Mini App) передає рядок `initData` у query-параметрі: `?initData=<url-encoded initData>`. Без нього — `{valid:false, reason:'no_init_data'}` і відповідь `401`.
2. Вузол `Validate InitData` (у кожного з 3 ендпоінтів даних є власна копія: `Validate InitData`, `WR-Render: Validate InitData`, `Xlsx: Validate InitData`) перевіряє:
   - підпис Ed25519 від Telegram (публічний ключ Telegram), токен бота не потрібен;
   - `auth_date` обов'язковий і не старший за 24 години;
   - витягує `userId`.
3. `Resolve Company (…)` шукає `userId` у `user_access` (`telegram_user_id`), повертає `company_id` і роль.
4. `Has Access (…)`: порожній `company_id` → та сама відповідь `401` (`Respond Unauthorized`, `Respond Weekly Render Unauthorized`, `Respond Xlsx Unauthorized`).
Помилка авторизації не розрізняє причини для клієнта: тіло завжди `{"error":"invalid or missing initData"}`.
Сторінки HTML (`/owner-view`, `/weekly-render`) авторизації не мають: це статичний шаблон, дані клієнт запитує окремо.
Оператор FDO (`company_id IS NULL` у `user_access`): активна компанія береться з `archi_bot_mode_state`; поведінка вебхуків для оператора **не перевірена** (потребує тесту T4–T6).

## 3. `GET /webhook/demo-archi-owner-view`
Відповідь `200`, `Content-Type: text/html; charset=utf-8`, `Cache-Control` задано у вузлі `Respond MiniApp HTML`. Тіло — одна HTML-сторінка з вбудованим скриптом, що викликає ендпоінт даних із `initData` Telegram WebApp.

## 4. `GET /webhook/demo-archi-owner-view-data?initData=…`
Відповідь `200 application/json`: об'єкт `data` з вузла `Build MiniApp Data`.

| Поле | Тип | Опис |
|---|---|---|
| `asOf` | string | дата оновлення даних `ДД.ММ.РРРР` (F-28) або `—` |
| `projects` | array\<Project\> | договори стадій (див. нижче) |
| `attention` | array | перелік проєктів, що потребують уваги |
| `counts` | object `{red, yellow, green, blocked}` | лічильники статусів |
| `totalContract`, `totalContractFmt` | number, string | сума контрактів |
| `pfc` | object | показники портфеля (таблиця План / Факт / Прогноз): `planProjects`, `planHours`, `planProfit`, `planRentPct`, `factRentPct`, `forecastRentPct`, `planRentContractPct`, `factRentContractPct`, `forecastRentContractPct`, `factProfit`, `forecastProfit`, `factProjects`, `forecastProjects`, `factHours`, `unpaidHours`, `forecastHours`, `kpMonthSent`, `kpYearSent`, `kpPlanYear`, `kpConversionPct`, `kpProjectedContracts`, `execIdx`, `effFcIdx`, `wp`, `fcSig`, `diff` |
| `rules` | object | пороги в тому вигляді, в якому їх бачить клієнт: `OPT_ETC_DROP`, `OPT_READY_MAX`, `RENT_DROP_PP`, `RENT_DROP_PP_RED`, `PROFIT_YELLOW_PCT`, `PROFIT_RED_PCT`, `CPI_RED`, `CPI_YELLOW`, `ETC_RED`, `ETC_YELLOW`, `UNPAID_YELLOW`, `UNPAID_RED`, `SLIP_RED_DAYS`, `BLOCK_RED_DAYS` |
| `views` | object | згруповані перегляди для панелі «Показник» (`rentDefs`, `profitDefs` тощо; групи `critical`/`attention`/`normal`) |

**Project** (одна картка): `id`, `name`, `dataUpdated`, `status` (`red`/`yellow`/`green`), `reds`, `yellows`, `signals[]`, `cls{}` (колір по показниках), `wr{}` (звіт ПМа), `blocker`, `contract`, `contractFmt`, `rentPlan`, `rentPlanFmt`, `noForecast`, `lastConfirmedForecast`, `rentForecast`, `rentForecastFmt`, `profitPlan`, `profitPlanFmt`, `profitForecast`, `profitForecastFmt`, `profitFact`, `profitFactFmt`, `executedWorkFmt`, `receivedFmt`, `actsFmt`, `moneyToCompleteTeamFmt`, `moneyToCompleteSubFmt`, `etcPlanFmt`, `etcFactFmt`, `etcPlanTotFmt`, `etcForecastFmt`, `etc`, `cpi`, `cpiFmt`, `cpiH`, `cpiHFmt`, `rentContractPlanFmt`, `rentContractFactFmt`, `rentContractForecastFmt`, `rentCostPlanFmt`, `rentCostFactFmt`, `rentCostForecastFmt`, `planHrs`, `factHrs`, `rawQ`, `rawS`, `rawP`, `rawEtcPlan`, `rawEtcForecast`, `wp{}`.

Правила значень (з коду):
- Числа без суфікса `Fmt` — `number | null`; `null` означає «даних немає», не 0 (BR-12).
- Поля з суфіксом `Fmt` — готові рядки для показу з розділювачем тисяч і валютою; відсутній прогноз подається як `🔴 Прогноз відсутній` (`rentForecastFmt`, `profitForecastFmt`) або `🔴 Не подано ПМом` (`etcForecastFmt`).
- Частка поля `rentPlan`/`rentForecast` — частка від одиниці (`0.2` = 20%), не відсоток.
- У відповіді присутні назви на кшталт `cpi`, `rentPlanFmt`: це історичні імена полів JSON, на екрані підписи інші (`CLAUDE.md` п. 14); перейменування — W1.8/W7.5.
- Колір розраховує код вузла `Build MiniApp Data` частково через значення з SQL; повний перенос у SQL — W1.8. **Поки клієнт отримує колір у `cls` і `status`, а не рахує його сам.**
- Статус `yellow` у структурі лишився, але за п. 15 для відхилень від плану не використовується (пороги = 0).

## 5. `GET /webhook/demo-archi-weekly-render` (HTML) і `…-data?initData=…` (JSON)
Дані (`Build Weekly Render Data`): `{ asOf: string, weekLabels: string[], projects: [{ id, dataUpdated, columns: Cell[] }] }`. `columns` = по одній комірці на тиждень зі знімка + остання комірка «Сьогодні» (`isToday: true`, `label: 'Сьогодні (Data Total)'`).
Поля комірки: `m1 {plan, forecast}` (рентабельність), `m2 {plan, fact, forecast, gap, signal}` (ETC), `m3 {spent, pm, fc, gap, gapSignal, eff, effSignal, exec, execSig}` (ланцюжок готовності), `m7x {actsToEv, paidToActs, planIdx, planSig, due, done, paidSig}`, `stages {ЕП, П, Р}` (готовність стадій; МБР у Weekly Render не показується), `m7 {date, prob}` (акт), `m8 {date, prob}` (документація), `plan`, `problems`, `help`, `comment` (тексти ПМа), `planExec`, `textsFrom`. Повний набір полів — `Build Weekly Render Data` (≈6 КБ).
Відповідь **без грошових сум** (BR-27): `contract_amount`, `actual_cost`, суми актів у цій відповіді не повертаються; перевірка — крок 7 аудиту (`08`).

## 6. `GET /webhook/demo-archi-export?initData=…`
Відповідь `200`, бінарний файл xlsx `archi_weekly_history.xlsx`, аркуш «Історія», перший рядок — заголовки. Рядок = проєкт (`project_id`), далі для кожного тижня знімка набір колонок з префіксом тижня: `<тиждень>_Рентабельність_прогноз_%`, `_Витрачено_часу_%`, `_Готовність_ПМа_%`, `_Готовність_за_прогнозом_%`, `_Розбіжність_готовності_пп`, `_Ефективність_годин`, `_Ефективність_виконання`, `_Акти_до_плану_на_дату`, `_Акти_виконано_з_запланованих`, `_Виставлено_до_освоєного_WIP`, `_Оплата_до_актів`, `_МБР_%`, `_ЕП_%`, `_П_%`, `_Р_%`, `_ETC_план_год`, `_ETC_факт_год`, `_ETC_прогноз_год`, `_ETC_Δ_год`, `_Ймовірність_акту`, `_Ймовірність_документації`, `_План_виконано`, `_План_виконано_%`. Якщо даних немає, повертається один рядок `project_id = «немає даних»`.

## 7. Telegram (вхідні події)
Вузол `Telegram Trigger` приймає лише `updates: ["message"]`. Не обробляються `callback_query`, `edited_message`, `channel_post`, `my_chat_member` (потрібно для W10). Типи вмісту повідомлення: текст, голос (`WR: Transcribe`), фото (`WR: Analyze Image`), документ PDF/TXT. Інший формат → `WR: Send Unsupported Format`. Користувач без запису в `user_access` → «⛔ Доступ не надано». Чи використовується секретний токен вебхука Telegram: **не перевірено** (n8n реєструє вебхук сам).
Команди й кнопки (за підписами в вузлах): `/status`, «📋 Статус звітів», «📊 Owner View», «📝 Тижневий звіт», «❓ Питання», «📖 Довідник», «📄 Договір», «🤝 Зустріч», `кошторис <id>`, «✅ Затвердити», `КП: N`, кнопки проєктів, «📤 Відправити», «📄 Чернетка», «✅ Фінал», «🆕 Новий». Кнопка Weekly Render — у меню вмісту; точний підпис не звірено. Деталі потоків — `13_USER_FLOWS.md`.

## 8. Зовнішні виклики
| Сервіс | Вузол | Модель / призначення | Таймаут і повтор |
|---|---|---|---|
| Anthropic | `Call Anthropic` | `claude-sonnet-4-6`, чат; `max_tokens 2600`, `temperature 0.2` | таймаут не задано, повтору немає |
| OpenAI | `WR: OpenAI Chat Model`, `WR: Transcribe`, `WR: Analyze Image` | `gpt-4o` звіт/імпорт/зустріч; транскрипція голосу; аналіз фото | немає |
| Anthropic | Morning Brief `Call Anthropic` | `claude-sonnet-4-6`, брифінг; `max_tokens 2000`, `temperature 0.2`, таймаут 90 с | `onError: continueRegularOutput` (шаблони-запас) |
| Supabase Postgres | вузли `postgres` | прямі SQL-запити (51 вузол core) | немає; `WR: Save Weekly Snapshot` — `retryOnFail` |
| Google Drive/Sheets | K6sm, RC7H | Кошторис, договір | спадковий адаптер |

## 9. Що відсутнє (борг, не вигадуємо)
- Зразки живих відповідей (знімок `owner-view-data` для демо-компанії) — потрібен підписаний `initData`; додається разом із тестом T4–T6.
- Контрактні тести (клієнт ↔ сервер).
- JSON Schema поля `signals[]`, `cls{}`, `wr{}`, `views{}`: структура вкладених об'єктів описана лише кодом `Build MiniApp Data`; детальний опис — після W1.8, коли обчислення перейдуть у SQL і форма стабілізується.
