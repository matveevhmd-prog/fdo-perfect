# ARCHI — репозиторій продукту

Оркестраційний шар над проектними даними архітектурно-будівельної компанії
(Telegram Chat-агент + Owner View Mini App + Щотижневий WR-цикл).

⚠️ **Цей репозиторій — публічний.** До 13.09.2026 продукт розроблявся напряму
в n8n і в чат-сесіях, без git. Це перше перенесення коду під версійний
контроль — репозиторій свідомо repurposed з порожнього `fdo-perfect`
(історичний сміттєвий репо), бо GitHub-інтеграція цієї сесії не мала права
створити новий репозиторій, а всі вільні репозиторії акаунту публічні.
Власник (Андрій Матвєєв) підтвердив push "як є" з прийняттям ризику —
див. `SECURITY.md`.

## Структура

```
workflows/
  DEMO_Archi_Agent_Core.json         — головний n8n workflow (id CKwCsGIwyw9feCY5,
                                        n8n instance osbbcopilot.app.n8n.cloud).
                                        Переекспортовано 04.10.2026,
                                        activeVersionId ea96092c-1e2a-42c4-900b-26cafbea4ac2,
                                        162 ноди (Фаза 6 — RELEASE_PLAN.md Розділ 9).
                                        ⚠️ Як завжди: цей файл застаріє одразу після
                                        наступної сесії редагування в n8n, якщо його
                                        не переекспортувати — перевіряти дату/versionId
                                        тут проти живого workflow, не довіряти мовчки.
  Archi_Protocol_Format_Helper.json  — діагностичний/scratch workflow
                                        (id LK4tBGMPiwIgpoki), read-only helper,
                                        не production-критичний

docs/
  ARCHI_TECH_SPEC_v2_0.md            — технічна специфікація, заголовок усередині
                                        v2.2 (оновлено 04.10.2026, звірено живим SQL/n8n)
  ARCHI_Obraz_Idealnoho_Rezultatu.md — методологія й образ ідеального результату,
                                        доповнено 26.09.2026 (Розділ 7 — урок про
                                        front-loaded стадії, §5.1 — Data Total тепер
                                        7 таблиць)
  archi_bot_gpt_analysis.md          — зовнішній аудит (ChatGPT), Owner Morning Test
  RELEASE_PLAN.md                    — план від 13.09.2026 до релізу, звірений
                                        з живим кодом; Розділ 9 (04.10.2026) —
                                        Фаза 6: Document Intake, PFC-блок Owner View,
                                        лічильник КП, уніфікація порогів кольору
                                        5%/10% — опубліковано, ЩЕ НЕ перевірено наживо

SECURITY.md                          — відомі проблеми безпеки, прийняті ризики;
                                        п.5 (26.09.2026) — Supabase RLS вимкнений
                                        на ключових таблицях; п.6 (04.10.2026) —
                                        нова таблиця kp_log теж без RLS, той самий
                                        клас проблеми; обидва НЕ виправлені, чекають
                                        рішення власника
```

## Що НЕ в цьому репозиторії (свідомо)

- `Archi Representative Telegram Bot` (n8n id `I3K5tBj0FWF1dbWb`) — окремий
  проєкт (представник замовника + Dispatcher), не частина ARCHI Owner
  View/WR-agent продукту. За рішенням власника — не чіпати, не включати сюди.
- Одноразові setup-workflow (`Archi Flat - Gate Setup M0.1`,
  `Archi Flat Link Test 01`, `Archi Flat - Fix Percent Format`,
  `DEMO Archi — Check Contract+Graphik`) — неактивні, історичні, не код
  продукту.
- Google Sheets документи (Кошторис, Protocol) — це зовнішні дані/адаптери,
  не код. ID перелічені в ТЗ, розділ "Environment Registry". **Flat і Weekly
  Log — прибрані з продукційного контуру workflow 25.09.2026** (RELEASE_PLAN.md
  Розділ 8); Google Sheets документи як такі не видалені, просто бот їх
  більше не читає.
- Тимчасовий workflow `SPhB65LRmYi8ff3R` ("DEMO Flat -- Get Real Formulas
  (Temp)") — писав у Weekly Log, зайвий після його видалення, **заархівований
  26.09.2026**.

## Як синхронізувати далі

n8n Cloud (Starter/Pro) не має вбудованого git-sync. Дисципліна поки що
ручна: перед і після кожної сесії редагування workflow в n8n — заново
експортувати JSON (`Download` у меню workflow) і закомітити сюди. Це
тимчасовий процес до автоматизації (backlog-пункт, не в поточному
release-плані).
