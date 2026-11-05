-- СТАТУС 05.11.2026: ЗАСТОСОВАНО (міграція w5_7_morning_brief_step1). Перевірка live SQL: archi_morning_brief(DEMO, 2026-11-05) → 14 проєктів, 45 кандидатів, топ-5 дій, 4 події у горизонті 7 днів.
-- ARCHI W5.7, крок 1 (05.11.2026). Рішення власника: CLAUDE.md п. 32. Лише додавання.
-- owner_prefs: час і дні ранкового брифінгу на користувача; archi_morning_brief: пріоритети і числа лише з SQL (LLM лише формулює).
-- Відкат: sql/2026-11-05_w5_7_morning_brief_step1_rollback.sql

CREATE TABLE public.owner_prefs (
  telegram_user_id bigint NOT NULL,
  company_id       uuid NOT NULL REFERENCES public.companies (company_id),
  brief_time       time NOT NULL DEFAULT '08:30',
  tz               text NOT NULL DEFAULT 'Europe/Kyiv',
  days             smallint[] NOT NULL DEFAULT '{1,2,3,4,5}',
  enabled          boolean NOT NULL DEFAULT false,
  last_sent_on     date,
  updated_at       timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (telegram_user_id, company_id)
);
ALTER TABLE public.owner_prefs ENABLE ROW LEVEL SECURITY;

-- Правила пріоритету (score, більше = вище; з одного проєкту — не більше 2 дій; у брифінг — топ-5):
--  blocker      100 + днів простою      (проєкт стоїть: останній звіт ПМа, блокер із типами)
--  act_due      90 − (дата − сьогодні)  (акт у плані: прострочений до 30 днів тому або за 7 днів вперед, статус «заплановано»)
--  doc_deadline 75 − (дата − сьогодні)  (дедлайн документації за 7 днів вперед)
--  meeting_due  65 − (дедлайн − сьогодні) (дія з журналу зустрічей: дедлайн від −14 до +2 днів)
--  etc_red      70 + etc_gap_pct_bac    (сигнал ETC червоний — archi_report_today)
--  rent_below   55 + (план − прогноз)   (прогноз рентабельності нижче плану)
--  no_forecast  50                      (прогнозу рентабельності немає)
--  no_report    60                      (з четверга: за поточний тиждень немає звіту ПМа)
CREATE FUNCTION public.archi_morning_brief(p_company uuid, p_asof date DEFAULT ((now() AT TIME ZONE 'Europe/Kyiv'))::date)
RETURNS jsonb LANGUAGE sql STABLE SET search_path = public AS $$
WITH pm AS (
  SELECT project_id FROM project_metrics WHERE company_id = p_company AND COALESCE(contract_type, 'stages') = 'stages'
), r AS (
  SELECT t.* FROM archi_report_today t JOIN pm USING (project_id) WHERE t.company_id = p_company
), snap AS (
  SELECT DISTINCT ON (s.project_id) s.project_id, s.week_start, s."блокер" AS bl
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
  'actions', COALESCE((SELECT jsonb_agg(jsonb_build_object('rank', rn, 'project_id', project_id, 'kind', kind, 'score', score, 'facts', facts) ORDER BY rn)
                         FROM (SELECT t.*, row_number() OVER (ORDER BY t.score DESC, t.project_id) AS rn FROM top t) z), '[]'::jsonb),
  'horizon_7d', COALESCE((SELECT jsonb_agg(jsonb_build_object('project_id', project_id, 'kind', kind, 'facts', facts) ORDER BY (facts->>'date'), project_id)
                           FROM cand WHERE kind IN ('act_due', 'doc_deadline') AND (facts->>'days_to')::int BETWEEN 0 AND 7), '[]'::jsonb))
$$;
