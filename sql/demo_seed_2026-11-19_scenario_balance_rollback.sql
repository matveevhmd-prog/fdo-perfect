-- Відкат балансу демо-сценаріїв 19.11.2026: повертає значення знімків 267 (DEMO-02) і 261 (DEMO-09), зняті live SQL перед зміною.
UPDATE public.wr_weekly_snapshots SET
  "готовність_pct" = '{"П":83,"Р":20,"ЕП":100,"МБР":100}'::jsonb,
  "залишок_прогноз_по_стадіях" = '{"П":25,"ЕП":0,"МБР":0}'::jsonb,
  "дедлайн_прогноз_по_стадіях" = '{"П":"2026-11-27","Р":"2026-11-27"}'::jsonb,
  "залишок_прогноз_год" = NULL,
  help_needed = '',
  problems = '❓ Відповіді нема (ПМ): ETC_прогноз Р'
WHERE id = 267 AND company_id = '00000000-0000-4000-8000-000000000001' AND project_id = 'DEMO-02';
UPDATE public.wr_weekly_snapshots SET help_needed = '' WHERE id = 261 AND company_id = '00000000-0000-4000-8000-000000000001' AND project_id = 'DEMO-09';
