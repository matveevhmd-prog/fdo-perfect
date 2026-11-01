-- Відкат перебалансування демо-сценаріїв (значення — live SQL 01.11.2026 до зміни). Застосовувати лише за рішенням власника.
UPDATE public.wr_weekly_snapshots SET
  "готовність_pct" = '{"П":100,"Р":40,"ЕП":100,"МБР":100}'::jsonb,
  "залишок_прогноз_по_стадіях" = '{"П":0,"Р":160,"ЕП":0,"МБР":0}'::jsonb,
  item_statuses = '[{"status":"done","item_number":1},{"status":"not_done","item_number":2}]'::jsonb,
  pm_comment = 'Проміжні рішення по П із замовником узгодили, акт по П готуємо.'
WHERE id = 256 AND project_id = 'DEMO-01';
UPDATE public.wr_plan_items SET status = 'not_done' WHERE id = 291 AND project_id = 'DEMO-01';

UPDATE public.wr_weekly_snapshots SET
  "готовність_pct" = '{"П":48,"Р":0,"ЕП":100,"МБР":100}'::jsonb,
  "залишок_прогноз_по_стадіях" = '{"П":90,"Р":240,"ЕП":0,"МБР":0}'::jsonb,
  "дедлайн_прогноз_по_стадіях" = '{"П":"2026-11-13","Р":"2026-12-25"}'::jsonb,
  plans_next_week = '1) Довести готовність П до 58%'
WHERE id = 261 AND project_id = 'DEMO-09';
UPDATE public.wr_plan_items SET item_text = 'Довести готовність П до 58%' WHERE id = 559 AND project_id = 'DEMO-09';

UPDATE public.wr_weekly_snapshots SET
  "готовність_pct" = '{"П":100,"Р":86,"ЕП":100,"МБР":100}'::jsonb,
  "залишок_прогноз_по_стадіях" = '{"П":0,"Р":180,"ЕП":0,"МБР":0}'::jsonb
WHERE id = 259 AND project_id = '22-24';
