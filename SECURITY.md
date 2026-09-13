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

**Дія, коли власник вирішить закрити:**
1. BotFather → revoke old token → новий токен.
2. У n8n: винести токен у credential/expression, прибрати з коду обох нод.
3. Оновити git-копію (сам токен у старих комітах все одно залишиться в
   історії — це не видаляється без переписування історії репозиторію).

## 2. 🔴 Weekly Render Data Webhook без авторизації (регресія)

**Факт:** `Weekly Render Data Webhook` (`demo-archi-weekly-render-data`)
підключений напряму до `Fetch All Project Metrics`, минаючи ноди
`WR-Render: Validate InitData` / `WR-Render: Is Valid InitData` — вони є у
workflow, але нічого на них не веде (мертві, orphaned). Будь-хто, хто знає
URL, отримує дані по всіх 10 проєктах без Telegram-авторизації.

Оригінальний `MiniApp Data Webhook` (owner view) підключений правильно —
перевірено окремо, там `Validate InitData → Is Valid InitData → Read DEMO
Flat` в одному ланцюгу.

**Статус:** ще не виправлено в живому n8n. **P0 — перший пункт
`docs/RELEASE_PLAN.md`, Фаза 0.**

## 3. Google Sheets credential, Postgres credential

Використовуються через n8n credential-посилання (id `ijBsXae1VQfiWISu`,
`9RgEysuE2hzWIIQq`) — самі секрети НЕ потрапляють в JSON-export, тільки
id/назва credential. Це безпечно для git.

## 4. Anthropic API

Викликається через `predefinedCredentialType` (credential id
`U5Ts0Bmqulc3foVf`) — так само безпечно, ключ не в JSON.
