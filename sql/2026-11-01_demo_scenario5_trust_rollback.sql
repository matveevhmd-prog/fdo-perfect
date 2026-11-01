-- Відкат сценарію 5 (значення — live SQL 01.11.2026 до зміни).
UPDATE public.wr_weekly_snapshots SET
  "готовність_pct" = '{"П":78,"Р":0,"ЕП":100,"МБР":100}'::jsonb,
  "розбіжність_готовності" = NULL
WHERE id = 255 AND project_id = '24-52';
UPDATE public.wr_weekly_snapshots SET
  "готовність_pct" = '{"П":55,"Р":0,"ЕП":100,"МБР":100}'::jsonb,
  problems = 'Проблем немає, замовник оплатив аванс значно вище виконаного обсягу.',
  pm_comment = 'Оплачено наперед, виконуємо за графіком.'
WHERE id = 261 AND project_id = 'DEMO-09';
