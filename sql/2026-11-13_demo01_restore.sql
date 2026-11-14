-- П0 (DEMO_FIX_PLAN_2026-11-13): відкат тестового звіту DEMO-01 за тиждень 2026-11-09 (B-21).
-- Причина: текст тесту DEMO-10 потрапив у звіт DEMO-01 (Р 26%, ETC 305). Дані демо (CLAUDE.md п. 18).
-- Виконання: DELETE знімка id=268 + archi_recalc. Відкат цього кроку: INSERT нижче (резервна копія рядка).
DELETE FROM public.wr_weekly_snapshots WHERE id = 268 AND project_id = 'DEMO-01' AND week_start = '2026-11-09';
SELECT public.archi_recalc('00000000-0000-4000-8000-000000000001'::uuid, 'DEMO-01');
-- ROLLBACK (повернути тестовий знімок):
-- INSERT INTO public.wr_weekly_snapshots (id, company_id, project_id, week_start, session_id, "готовність_pct", "залишок_прогноз_по_стадіях", "дедлайн_прогноз_по_стадіях", "ймовірність_акту", "ймовірність_документації", "блокер", plans_next_week, problems, help_needed, pm_comment, item_statuses, created_at)
-- VALUES (268, '00000000-0000-4000-8000-000000000001', 'DEMO-01', '2026-11-09', '304884647', '{"П":100,"Р":26,"ЕП":100,"МБР":100}', '{"П":0,"Р":305,"ЕП":0,"МБР":0}', '{"Р":"2026-12-04"}', 9, 8, '{"types":[]}', 'продовжити ЕР', '', '', '', '[]', '2026-11-13 16:57:44.697023+00');
