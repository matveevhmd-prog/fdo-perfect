# Відомі проблеми безпеки — ARCHI

Факти, перевірені прямо в коді 13.09.2026. Не пом'якшено, не приховано.

## 1. 🔴 Telegram bot token захардкожений у коді, репозиторій публічний

**Факт:** живий токен `@archi_demo_bot`
(`8813476306:AAGvcE5Mys8Pg5__DtE03O6rBcjCu-0TVXk`) лежить відкритим текстом
у двох нодах `workflows/DEMO_Archi_Agent_Core.json`:
- `Validate InitData`
- `WR-Render: Validate InitData`

Токен потрібен там для HMAC-перевірки Telegram Mini App `initData` —
легітимна причина, але реалізовано неправильно (має бути n8n credential
або env, не літерал у коді).

**Рішення власника (13.09.2026):** запушити як є в публічний репозиторій,
ризик прийнято свідомо. Це ЗМІНЮЄ рівень ризику порівняно з попереднім
записом у ТЗ ("токен уже потрапив у зовнішні AI-сервіси при аудиті,
ротація відкладена після демо") — тепер токен додатково у публічній
git-історії, GitHub secret-scanning майже напевно його підхопить.

**Рішення власника (13.09.2026, повторно підтверджено):** токен НЕ
ротується. Ніколи. Це фінальне рішення, не "відкладено на потім" — не
пропонувати повторно, не включати в release-план як задачу. Ризик
постійного витоку прийнятий назавжди.

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
