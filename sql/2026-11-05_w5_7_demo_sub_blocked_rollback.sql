-- Відкат демо-сценарію sub_blocked (повертає порожнє значення, яке було до змін).
UPDATE public.wr_weekly_snapshots SET problems = ''
 WHERE company_id = '00000000-0000-4000-8000-000000000001' AND project_id = 'DEMO-08' AND week_start = DATE '2026-10-26' AND problems = 'Субпідрядник по ОВіК не починає роботу, чекає аванс.';
