# ARCHI — перехідний промпт v5
## Дата: 02.11.2026 | Версія: v5 (замінює v4 від 29.10 і перехідний промпт EVM від 31.10; розділи 2–8, 10–15 v3 — `TRANSITION_PROMPT_2026-10-25.md` — лишаються довідковими до `TECH_SPEC` v3.1)

> **Як читати.** `CLAUDE.md` → `docs/DECISIONS_REGISTER.md` → `docs/ROADMAP_TO_RELEASE.md` → цей файл → `docs/RELEASE_PLAN.md` з кінця. Позначки: **Факт** (перевірено), **[Припущення]**, **Потребує перевірки**. Індекс усіх документів — `docs/README.md`. Перед комітом документації: `python3 scripts/check_docs.py`.

## 1. Живий стан (02.11.2026)

**Доповнення 13.11.2026 (`RELEASE_PLAN` §195):** core `CKwCsGIwyw9feCY5` — `activeVersionId c9a11286-ba6d-4406-a832-61917a7de21b`, 197 вузлів (B-20: швидкий Щотижневий рендер, `d97dbabe`; B-17: валідатор відповіді чату); відкат `d97dbabe-a47c-43f7-b832-65ee41820ca3`, далі `4a5df71b-ba97-42a8-bbdd-179ce53fdfeb`. Беклог і план: `docs/DEMO_BACKLOG_2026-11-13.md`, `docs/DEMO_FIX_PLAN_2026-11-13.md`.
**Доповнення 11.11.2026 (`RELEASE_PLAN` §190):** core `CKwCsGIwyw9feCY5` — `activeVersionId 4a5df71b-ba97-42a8-bbdd-179ce53fdfeb`, 197 вузлів (V10: onError/повтор/запасні повідомлення, temperature 0.2; відкат `eb57069b-a23e-4879-959f-9c0516c178d9`); Morning Brief `911fa93b-b2df-4af5-89fc-1e7bded18803` (відкат `a3324b54-fd60-4e38-a5b7-60e18f18408d`); новий workflow «ARCHI: LLM Health Check» `Sna7JWxq3BpRDJIs` (щодня 07:30). Рядок core `978db8b8` нижче застарів.

**Доповнення 11.11.2026:** входить у core `4a5df71b`: V5 ( формат чисел Weekly Render і Owner View; V9: 1А 2А 3Б 4Б; відкат `d3fa185e`, до V5 `229f011a`); Supabase — `company_thresholds` для DEMO (план ×0,2, `sql/2026-11-08_v9_demo_plan_scale*.sql`); `CLAUDE.md` п. 36 і потік W12 «Фінансова ліквідність власника» (oneBfinance, касовий розрив, Q4–Q6) — лише зафіксовано на карті (§193), не реалізовано; відкрито: п. 7 V4 (підписи Weekly Render), V3, V6–V8 (акаунт власника).
**Доповнення 07.11.2026:** Morning Brief `J3Oqcaa2YBEsVSng` — формат v2 (Insight → Impact → Action), `activeVersionId a3324b54-fd60-4e38-a5b7-60e18f18408d`, відкат `cb4b50e8-1acd-457c-a37f-16647d00fcb7` (`RELEASE_PLAN` §186); Supabase — міграція `w5_7_brief_action_types`.
**Доповнення 07.11.2026 (п. 35):** пауза W1; пріоритет — демо-відео, `docs/DEMO_VIDEO_PLAN_2026-11-07.md`, старт нової сесії — `docs/START_PROMPT_DEMO.md`.
**Доповнення 07.11.2026:** Supabase — міграція W1.8 крок 1 (`archi_project_signals`, `archi_threshold_req`, `RELEASE_PLAN` §184); n8n без змін.
**Доповнення 05.11.2026:** другий workflow «ARCHI: Morning Brief» `J3Oqcaa2YBEsVSng` (11 вузлів, опублікований, розсилка ввімкнена, W5.7, `RELEASE_PLAN` §174); core `a4c89c3c`, 191 вузол — без змін.
- **n8n core** `CKwCsGIwyw9feCY5`: `activeVersionId eb57069b-a23e-4879-959f-9c0516c178d9`, 193 вузли (V5, 07.11.2026: формат чисел у `Build Weekly Render HTML`; відкат `229f011a-5a3f-4d34-b7bf-a55efbab6af9` = вміст `978db8b8`; DR-14, 05.11.2026: +`Send Thinking Ack`, `Send LLM Fallback`; відкат `a4c89c3c-3892-40d0-91e6-7e9ba5eb49d9`); раніше 191 вузол (колір hero-карток 04.11.2026; перед тим W1 M5 `eab0cf36`, 03.11.2026; відкат до M5 — `eab0cf36`); K6sm `23c5765e`, RC7H `6a8d9dbe`, збігається з `workflows/DEMO_Archi_Agent_Core.json` (звірено 03.11.2026). Остання публікація 03.11.2026 (`RELEASE_PLAN` §160, виправлено `WR: Detect Doc Type`); попередня `bc449cbd` — ID відкату. Sub-workflow K6sm `K6smBd5xWZLWx9rr` — активна `cf904641` (звірено 01.11); у git його немає.
- **Supabase** `bxawceksdkqlbkdgjvyz`: нове з 01.11.2026 — `evm_packages` (100 демо-пакетів), `evm_package_done` (порожня), функції `evm_classic_indices`, `evm_classic_at`, в'ю `evm_classic_today`; `project_metrics` 18 рядків; `wr_weekly_snapshots` 101 рядок (`live SQL`).
- **Репозиторій** `matveevhmd-prog/fdo-perfect`, `main`.

## 2. Карта
| Фінал | Стан |
|---|---|
| Ф1. Демо власникам АБ-компаній | показ 03.11.2026 **скасовано** (`CLAUDE.md` п. 24); демо-дані — сценарний актив |
| Ф2. Реліз | критерії R-1…R-13 — `ROADMAP_TO_RELEASE.md` §2 |
| Ф3. Перші клієнти | потік W1 (багатоклієнтність і безпека) першим; блокують OD-1…OD-6 |

**Наступна сесія — CTO Senior (штаб)** за `docs/START_PROMPT_HQ.md`; пакет передачі — `docs/HANDOVER_CTO.md`. Інші сесії закриваються після результату (`CLAUDE.md` п. 20).

## 3. Що зроблено після v4 (29.10.2026 → 02.11.2026, `RELEASE_PLAN`)
- §133–§139: аудит документації й рішення за ним; Q1/Q8 виправлено.
- §140–§141: правило кольору п. 15 (від'ємне = 🔴) на індекси й виконання плану.
- §142–§144: гілка «EVM (класичний)»: джерело плану — Supabase (п. 17), таблиці, функції, в'ю.
- §145: CTO Checkpoint 01.11.2026 (P0 0 · P1 3 · P2 9).
- §146–§148: живий цикл звітів С1, перебалансування демо-сценаріїв, сценарій 5.
- §149–§155: єдина карта, факти з коду, відповіді власника, реєстр рішень, індекс і перевірка документації.

## 4. Відкрито
- Рішення власника: `ROADMAP_TO_RELEASE.md` розділ 6 (OD-N) та `DECISIONS_REGISTER.md` розділ C (суперечності).
- Борг і знахідки: `CTO_CHECKPOINT_01.11.2026.md`.
- Прогалини документації: `docs/ARCHI_FEATURES_v1.md` («3 фічі: що входить/не входить», запланований у чернетці демо, не створений) — W0.5 карти; `TECH_SPEC` v3.1 — PR фіналізації.

## 5. Уроки сесії 01–02.11.2026 (для профільної інструкції)
1. Перш ніж стверджувати, що чогось «немає в документах», шукати по **всіх** `docs/*.md` і `archive/`, не по вибраних файлах (помилка з `FEATURE_IDEAS.md`).
2. Закрите рішення власника записується в `CLAUDE.md` і `DECISIONS_REGISTER.md` тієї ж відповіді; рішення, розкидані по документах, породжують блукання.
3. Номери (пункти `CLAUDE.md`, розділи `RELEASE_PLAN`) після паралельних злиттів перевіряти: `python3 scripts/check_docs.py`.
4. Рекомендацію давати лише після читання документів і коду; «чого не знаю» перевіряти кодом (власник: «прочитай код»).
5. Архітектурні рішення, які власник бачить як блукання, закривати одним документом-картою, а не серією сесій.

## 6. Інфраструктура
Реєстр — `ARCHI_TECH_SPEC_v3_1.md` §6 та `TRANSITION_PROMPT_2026-10-25.md` §4 (K6sm, RC7H `RC7HNVlJtuPLtvYV`, Sheets Helper `nGcSyWfuMO7vjTn6`, Representative Bot `I3K5tBj0FWF1dbWb` — не чіпати).
