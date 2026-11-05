-- Статус: ЗАСТОСОВАНО в Supabase 05.11.2026 (apply_migration), перевірено на DEMO.
-- ARCHI W5.7, крок 1b (05.11.2026). Доповнення до 2026-11-05_w5_7_morning_brief_step1.sql (CREATE OR REPLACE тієї ж функції).
-- + правило sub_blocked (власник 05.11.2026): у «Проблемах» останнього звіту ПМа «підрядник не починає роботу, чекає аванс» або «підрядник не отримав оплату, не віддає роботу» (регулярні вирази; вага 85)
-- + advice на кожну дію: адресат за роллю, режим (нарада 1×1 / повідомлення / дзвінок / рішення), код мети (правила «подія → адресат і дія»).
-- Відкат: повторити CREATE OR REPLACE з 2026-11-05_w5_7_morning_brief_step1.sql (без advice і sub_blocked).
CREATE OR REPLACE FUNCTION public.archi_morning_brief(p_company uuid, p_asof date DEFAULT ((now() AT TIME ZONE 'Europe/Kyiv'))::date)
RETURNS jsonb LANGUAGE sql STABLE SET search_path = public AS $$
WITH pm AS (
  SELECT project_id FROM project_metrics WHERE company_id = p_company AND COALESCE(contract_type, 'stages') = 'stages'
), r AS (
  SELECT t.* FROM archi_report_today t JOIN pm USING (project_id) WHERE t.company_id = p_company
), snap AS (
  SELECT DISTINCT ON (s.project_id) s.project_id, s.week_start, s."блокер" AS bl, s.problems
    FROM wr_weekly_snapshots s JOIN pm USING (project_id) WHERE s.company_id = p_company
   ORDER BY s.project_id, s.week_start DESC
), cand AS (
  SELECT s.project_id, 'blocker'::text AS kind, (100 + GREATEST(p_asof - (s.bl->>'since')::date, 0))::numeric AS score,
         jsonb_build_object('days', p_asof - (s.bl->>'since')::date, 'since', s.bl->>'since', 'types', s.bl->'types', 'need', s.bl->>'need') AS facts
    FROM snap s
   WHERE jsonb_typeof(s.bl->'types') = 'array' AND jsonb_array_length(s.bl->'types') > 0 AND s.bl->>'since' IS NOT NULL
  UNION ALL
  SELECT ps.project_id, 'act_due', (90 - (ps."дата_план" - p_asof))::numeric,
         jsonb_build_object('stage', ps."стадія", 'date', ps."дата_план", 'days_to', ps."дата_план" - p_asof, 'amount', ps."сума_план", 'probability', ps."ймовірність_план")
    FROM payment_schedule ps JOIN pm USING (project_id)
   WHERE ps.company_id = p_company AND ps."подія" = 'акт' AND ps."статус_план" = 'заплановано'
     AND ps."дата_план" BETWEEN p_asof - 30 AND p_asof + 7
  UNION ALL
  SELECT ps.project_id, 'doc_deadline', (75 - (ps."дата_план" - p_asof))::numeric,
         jsonb_build_object('stage', ps."стадія", 'date', ps."дата_план", 'days_to', ps."дата_план" - p_asof, 'probability', ps."ймовірність_план")
    FROM payment_schedule ps JOIN pm USING (project_id)
   WHERE ps.company_id = p_company AND ps."подія" = 'документація' AND ps."дата_план" BETWEEN p_asof AND p_asof + 7
  UNION ALL
  SELECT m.project_id, 'meeting_due', (65 - (m."дедлайн" - p_asof))::numeric,
         jsonb_build_object('action', m."рішення_дія", 'owner', m."відповідальний", 'deadline', m."дедлайн", 'days_to', m."дедлайн" - p_asof)
    FROM meeting_log m JOIN pm USING (project_id)
   WHERE m.company_id = p_company AND m."дедлайн" BETWEEN p_asof - 14 AND p_asof + 2
  UNION ALL
  SELECT s.project_id, 'sub_blocked', 85::numeric,
         jsonb_build_object('week_start', s.week_start, 'quote', left(s.problems, 240),
           'case', CASE WHEN s.problems ~* '(підрядн|субпідрядн)[^.;\n]{0,80}(не\s+почин|чека[єе]\s+аванс|аванс)' THEN 'wait_advance' ELSE 'unpaid_no_delivery' END)
    FROM snap s
   WHERE s.problems ~* '(підрядн|субпідрядн)[^.;\n]{0,80}(не\s+почин|чека[єе]\s+аванс|аванс)'
      OR s.problems ~* '(підрядн|субпідрядн)[^.;\n]{0,80}(не\s+отрима[вл]|не\s+оплач|не\s+віддає|не\s+віддав)'
  UNION ALL
  SELECT r.project_id, 'etc_red', (70 + COALESCE(r.etc_gap_pct_bac, 0))::numeric,
         jsonb_build_object('gap_hours', r.etc_gap_hours, 'gap_pct_bac', r.etc_gap_pct_bac, 'etc_fact', r.etc_fact_hours, 'etc_forecast', r.etc_forecast_hours)
    FROM r WHERE r.etc_gap_signal = 'red'
  UNION ALL
  SELECT r.project_id, 'rent_below', (55 + (r.rent_plan_pct - r.rent_forecast_pct))::numeric,
         jsonb_build_object('plan_pct', r.rent_plan_pct, 'forecast_pct', r.rent_forecast_pct)
    FROM r WHERE r.rent_forecast_pct IS NOT NULL AND r.rent_plan_pct IS NOT NULL AND r.rent_forecast_pct < r.rent_plan_pct
  UNION ALL
  SELECT r.project_id, 'no_forecast', 50::numeric, '{}'::jsonb FROM r WHERE r.rent_forecast_pct IS NULL
  UNION ALL
  SELECT pm.project_id, 'no_report', 60::numeric, jsonb_build_object('week_start', date_trunc('week', p_asof)::date)
    FROM pm
   WHERE EXTRACT(isodow FROM p_asof) >= 4
     AND NOT EXISTS (SELECT 1 FROM wr_weekly_snapshots s WHERE s.company_id = p_company AND s.project_id = pm.project_id AND s.week_start = date_trunc('week', p_asof)::date)
), ranked AS (
  SELECT c.*, row_number() OVER (PARTITION BY project_id ORDER BY score DESC) AS rp FROM cand c
), top AS (
  SELECT * FROM ranked WHERE rp <= 2 ORDER BY score DESC, project_id LIMIT 5
)
SELECT jsonb_build_object(
  'company_id', p_company,
  'as_of', p_asof,
  'data_updated_at', (SELECT max(data_updated_at) FROM r),
  'projects_total', (SELECT count(*) FROM pm),
  'candidates_total', (SELECT count(*) FROM cand),
  'actions', COALESCE((SELECT jsonb_agg(jsonb_build_object('rank', rn, 'project_id', project_id, 'kind', kind, 'score', score, 'facts', facts,
                       'advice', CASE kind
                         WHEN 'blocker' THEN CASE WHEN facts->'types' ? 'замовник' THEN jsonb_build_object('to_role','Власник','mode','дзвінок замовнику','purpose','blocker_customer')
                                                  WHEN facts->'types' ? 'гроші' THEN jsonb_build_object('to_role','Фіндиректор','mode','повідомлення','purpose','blocker_money')
                                                  ELSE jsonb_build_object('to_role','Власник','mode','рішення про ресурс','purpose','blocker_people') END
                         WHEN 'sub_blocked' THEN jsonb_build_object('to_role','Фіндиректор','mode','повідомлення','purpose','sub_payment')
                         WHEN 'act_due' THEN CASE WHEN (facts->>'days_to')::int < 0 THEN jsonb_build_object('to_role','Фіндиректор','mode','повідомлення','purpose','act_overdue')
                                                  ELSE jsonb_build_object('to_role','ПМ проєкту','mode','повідомлення','purpose','act_soon') END
                         WHEN 'doc_deadline' THEN jsonb_build_object('to_role','ПМ проєкту','mode','повідомлення','purpose','doc_deadline')
                         WHEN 'meeting_due' THEN jsonb_build_object('to_role','Відповідальний з наради','mode','повідомлення','purpose','meeting_action')
                         WHEN 'etc_red' THEN jsonb_build_object('to_role','ПМ проєкту','mode','нарада 1×1','purpose','etc_over')
                         WHEN 'rent_below' THEN jsonb_build_object('to_role','ПМ проєкту','mode','нарада 1×1','purpose','rent_below_plan')
                         WHEN 'no_forecast' THEN jsonb_build_object('to_role','ПМ проєкту','mode','повідомлення','purpose','forecast_missing')
                         WHEN 'no_report' THEN jsonb_build_object('to_role','ПМ проєкту','mode','повідомлення','purpose','report_missing')
                       END) ORDER BY rn)
                         FROM (SELECT t.*, row_number() OVER (ORDER BY t.score DESC, t.project_id) AS rn FROM top t) z), '[]'::jsonb),
  'horizon_7d', COALESCE((SELECT jsonb_agg(jsonb_build_object('project_id', project_id, 'kind', kind, 'facts', facts) ORDER BY (facts->>'date'), project_id)
                           FROM cand WHERE kind IN ('act_due', 'doc_deadline') AND (facts->>'days_to')::int BETWEEN 0 AND 7), '[]'::jsonb))
$$;
