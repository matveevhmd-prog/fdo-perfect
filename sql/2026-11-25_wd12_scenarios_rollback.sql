-- Відкат пакета WD.12 (п. 18): повернути початкові значення трьох записів звітів ПМа (25.11.2026).
UPDATE public.wr_weekly_snapshots SET problems = 'Субпідрядник по ОВіК не починає роботу, чекає аванс.'
 WHERE id = 264 AND company_id = '00000000-0000-4000-8000-000000000001' AND project_id = 'DEMO-08';
UPDATE public.wr_weekly_snapshots SET problems = 'Невелика затримка погодження з замовником, на терміни не впливає.'
 WHERE id = 256 AND company_id = '00000000-0000-4000-8000-000000000001' AND project_id = 'DEMO-01';
UPDATE public.wr_weekly_snapshots SET "залишок_прогноз_по_стадіях" = '{"П": 70, "Р": 200, "ЕП": 0, "МБР": 0}'::jsonb
 WHERE id = 261 AND company_id = '00000000-0000-4000-8000-000000000001' AND project_id = 'DEMO-09';
