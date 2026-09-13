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
                                        n8n instance osbbcopilot.app.n8n.cloud),
                                        живий export станом на 13.09.2026,
                                        versionId 85cc4954-a4ff-45be-8912-fb35cd23b7c6
  Archi_Protocol_Format_Helper.json  — діагностичний/scratch workflow
                                        (id LK4tBGMPiwIgpoki), read-only helper,
                                        не production-критичний

docs/
  ARCHI_TECH_SPEC_v2_0.md            — технічна специфікація (05.09.2026)
  ARCHI_Obraz_Idealnoho_Rezultatu.md — методологія й образ ідеального результату
  archi_bot_gpt_analysis.md          — зовнішній аудит (ChatGPT), Owner Morning Test
  RELEASE_PLAN.md                    — план від 13.09.2026 до релізу, звірений
                                        з живим кодом (не тільки з документами)

SECURITY.md                          — відомі проблеми безпеки, прийняті ризики
```

## Що НЕ в цьому репозиторії (свідомо)

- `Archi Representative Telegram Bot` (n8n id `I3K5tBj0FWF1dbWb`) — окремий
  проєкт (представник замовника + Dispatcher), не частина ARCHI Owner
  View/WR-agent продукту. За рішенням власника — не чіпати, не включати сюди.
- Одноразові setup-workflow (`Archi Flat - Gate Setup M0.1`,
  `Archi Flat Link Test 01`, `Archi Flat - Fix Percent Format`,
  `DEMO Archi — Check Contract+Graphik`) — неактивні, історичні, не код
  продукту.
- Google Sheets документи (Кошторис, Flat, Protocol, Weekly Log) — це
  зовнішні дані/адаптери, не код. ID перелічені в ТЗ, розділ "Environment
  Registry".

## Як синхронізувати далі

n8n Cloud (Starter/Pro) не має вбудованого git-sync. Дисципліна поки що
ручна: перед і після кожної сесії редагування workflow в n8n — заново
експортувати JSON (`Download` у меню workflow) і закомітити сюди. Це
тимчасовий процес до автоматизації (backlog-пункт, не в поточному
release-плані).
