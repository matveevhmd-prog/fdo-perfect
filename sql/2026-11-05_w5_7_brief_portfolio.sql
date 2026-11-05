-- Статус: ЗАСТОСОВАНО 05.11.2026 (apply_migration w5_7_brief_portfolio_block). W5.7, BR-51: блок «Стан портфеля».
-- Додає в jsonb archi_morning_brief ключ 'portfolio' (кількості проєктів/подій за сигналами SQL). Патчить поточне визначення функції.
-- Відкат: повторити CREATE OR REPLACE з 2026-11-05_w5_7_morning_brief_step1b.sql (версія без 'portfolio').
DO $$ DECLARE d text; BEGIN
SELECT pg_get_functiondef('public.archi_morning_brief(uuid,date)'::regprocedure) INTO d;
IF position($q$'projects_total', (SELECT count(*) FROM pm),$q$ in d) = 0 THEN RAISE EXCEPTION 'pattern not found'; END IF;
IF position($q$'portfolio'$q$ in d) > 0 THEN RAISE EXCEPTION 'already patched'; END IF;
d := replace(d, $q$'projects_total', (SELECT count(*) FROM pm),$q$,
$q$'projects_total', (SELECT count(*) FROM pm),
  'portfolio', jsonb_build_object(
    'blocked', (SELECT count(DISTINCT project_id) FROM cand WHERE kind = 'blocker'),
    'sub_blocked', (SELECT count(DISTINCT project_id) FROM cand WHERE kind = 'sub_blocked'),
    'acts_overdue', (SELECT count(*) FROM cand WHERE kind = 'act_due' AND (facts->>'days_to')::int < 0),
    'acts_soon', (SELECT count(*) FROM cand WHERE kind = 'act_due' AND (facts->>'days_to')::int >= 0),
    'etc_red', (SELECT count(DISTINCT project_id) FROM cand WHERE kind = 'etc_red'),
    'rent_below', (SELECT count(DISTINCT project_id) FROM cand WHERE kind = 'rent_below'),
    'no_forecast', (SELECT count(DISTINCT project_id) FROM cand WHERE kind = 'no_forecast'),
    'no_report', (SELECT count(DISTINCT project_id) FROM cand WHERE kind = 'no_report')),$q$);
EXECUTE d;
END $$;
