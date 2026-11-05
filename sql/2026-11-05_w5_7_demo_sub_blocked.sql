-- Статус: ЗАСТОСОВАНО 05.11.2026. Демо-сценарій (CLAUDE.md п. 18, власник 05.11.2026): «підрядник чекає аванс».
-- Проєкт DEMO-08, тиждень 26.10.2026: у «Проблемах» ПМа — слова-тригер правила sub_blocked (archi_morning_brief).
UPDATE public.wr_weekly_snapshots SET problems = 'Субпідрядник по ОВіК не починає роботу, чекає аванс.'
 WHERE company_id = '00000000-0000-4000-8000-000000000001' AND project_id = 'DEMO-08' AND week_start = DATE '2026-10-26' AND COALESCE(problems, '') = '';
