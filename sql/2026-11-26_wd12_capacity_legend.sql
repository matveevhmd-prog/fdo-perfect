-- СТАТУС 26.11.2026: НЕ ЗАСТОСОВАНО (репетиція в транзакції — див. RELEASE_PLAN, WD.12).
-- ARCHI WD.12 (CLAUDE.md п. 44): легенда демо-компанії — 50 людей, 35 списують час у проєкти,
-- 35 x 160 = 5 600 год/міс, 67 200 год/рік. Власник 26.11.2026: Workload (P-02) = маяк «залучати нові проєкти».
-- Змінює ЛИШЕ перевизначення для компанії DEMO в company_thresholds (п. 30 D4). Глобальні значення archi_thresholds не чіпає.
-- Відкат: sql/2026-11-26_wd12_capacity_legend_rollback.sql
-- Споживач (факт, grep workflows/DEMO_Archi_Agent_Core.json): вузол «Build MiniApp Data» через rule('plan_year_hours'|'plan_year_projects').
--   Наслідок: P-01 (план проєктів 14 -> 56), P-02 (план годин 16 800 -> 67 200), P-06 (план КП = проєкти / 20% конверсії: 70 -> 280).
-- plan_year_contract (9 450 000) і plan_year_profit (1 890 000) НЕ змінюються цим пакетом: див. примітку в RELEASE_PLAN.

UPDATE public.company_thresholds
   SET value = 67200,
       note = 'DEMO: легенда п. 44 — 35 виконавців x 160 год x 12 міс (WD.12, 26.11.2026)',
       updated_at = now()
 WHERE company_id = '00000000-0000-4000-8000-000000000001' AND key = 'plan_year_hours';

UPDATE public.company_thresholds
   SET value = 56,
       note = 'DEMO: 67 200 год / 1 200 год на середній проєкт (власник 11.10.2026; WD.12, 26.11.2026)',
       updated_at = now()
 WHERE company_id = '00000000-0000-4000-8000-000000000001' AND key = 'plan_year_projects';
