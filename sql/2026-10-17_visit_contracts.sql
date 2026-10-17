-- ARCHI 17.10.2026: договір АН «оплата за виїзд» як окремий проєкт (contract_type='visit').
-- Відкат: archi_recalc_stages (з фільтром contract_type) = оригінальна archi_recalc; щоб повернути оригінал —
-- CREATE OR REPLACE archi_recalc з тілом archi_recalc_stages без умови contract_type; дані — з _bak_20261017_project_metrics.
CREATE TABLE IF NOT EXISTS public._bak_20261017_project_metrics AS SELECT * FROM public.project_metrics;
ALTER TABLE public._bak_20261017_project_metrics ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.project_metrics
  ADD COLUMN IF NOT EXISTS contract_type text NOT NULL DEFAULT 'stages',
  ADD COLUMN IF NOT EXISTS parent_project_id text,
  ADD COLUMN IF NOT EXISTS visits_plan integer,
  ADD COLUMN IF NOT EXISTS visit_price numeric,
  ADD COLUMN IF NOT EXISTS visit_hours numeric,
  ADD COLUMN IF NOT EXISTS visits_done integer;

-- 1) стара archi_recalc -> archi_recalc_stages (лише contract_type='stages'); логіка стадій не змінюється
DO $do$
DECLARE d text; d2 text;
BEGIN
  d := pg_get_functiondef('public.archi_recalc(text)'::regprocedure);
  d2 := replace(d, 'FUNCTION public.archi_recalc(', 'FUNCTION public.archi_recalc_stages(');
  d2 := replace(d2, 'SELECT * FROM public.project_metrics WHERE p_project IS NULL OR project_id = p_project',
                    'SELECT * FROM public.project_metrics WHERE COALESCE(contract_type, ''stages'') = ''stages'' AND (p_project IS NULL OR project_id = p_project)');
  IF d2 = d OR position('archi_recalc_stages' in d2) = 0 OR position('COALESCE(contract_type' in d2) = 0 THEN
    RAISE EXCEPTION 'archi_recalc rewrite did not apply';
  END IF;
  EXECUTE d2;
END $do$;

-- 2) візитні договори: Факт і Прогноз (план — з Кошторису)
CREATE OR REPLACE FUNCTION public.archi_recalc_visit(p_project text DEFAULT NULL::text)
 RETURNS integer LANGUAGE sql AS $f$
WITH pm AS (
  SELECT * FROM public.project_metrics WHERE contract_type = 'visit' AND (p_project IS NULL OR project_id = p_project)
),
hrs AS (
  SELECT t.project_id, sum(t."години") AS h,
         sum(t."години" * COALESCE(r.razom_grn_god, m.real_rate_team_hour)) AS cost
  FROM public.time_log t JOIN pm m ON m.project_id = t.project_id
  LEFT JOIN public.rates r ON r.posada = t."виконавець"
  WHERE t."статус" = 'confirmed' GROUP BY 1
),
money AS (
  SELECT project_id,
         sum("сума") FILTER (WHERE "тип" = 'оплата_субпідряднику') AS sub_paid,
         sum("сума") FILTER (WHERE "тип" = 'акт_підписаний') AS acts,
         count(*) FILTER (WHERE "тип" = 'акт_підписаний') AS visits,
         sum("сума") FILTER (WHERE "тип" = 'надходження_від_замовника') AS received
  FROM public.money_log WHERE "статус" = 'confirmed' GROUP BY 1
),
calc AS (
  SELECT m.project_id, COALESCE(h.h, 0) AS ah,
         round(COALESCE(h.cost, 0) + COALESCE(mo.sub_paid, 0), 2) AS ac,
         COALESCE(mo.acts, 0) AS acts, COALESCE(mo.received, 0) AS rec,
         LEAST(COALESCE(mo.visits, 0), m.visits_plan)::int AS vd,
         m.visits_plan, m.visit_hours, m.real_rate_team_hour AS rate, m.bac,
         m.visits_plan * m.visit_price AS contract
  FROM pm m LEFT JOIN hrs h ON h.project_id = m.project_id LEFT JOIN money mo ON mo.project_id = m.project_id
),
fin AS (
  SELECT c.*, (c.visits_plan - c.vd) * c.visit_hours AS etc,
         round(c.ac + (c.visits_plan - c.vd) * c.visit_hours * c.rate, 2) AS cost_final,
         c.vd::numeric / NULLIF(c.visits_plan, 0) AS pct
  FROM calc c
),
upd AS (
  UPDATE public.project_metrics m SET
    -- contract_amount/planned_hours/bac НЕ пишемо: тригер archi_recalc_plan спрацьовує на UPDATE OF цих колонок (рекурсія)
    visits_done = f.vd,
    actual_hours = f.ah,
    hours_remaining = f.visits_plan * f.visit_hours - f.ah,
    percent_execution = round(f.ah / NULLIF(f.visits_plan * f.visit_hours, 0) * 100, 1),
    actual_cost = f.ac,
    acts_amount = f.acts,
    money_received = f.rec,
    etc_forecast_total_hours = f.etc,
    stage_data = NULL,
    money_to_completion_team = round(f.etc * f.rate, 2),
    money_to_completion_subcontract = 0,
    cost_final_forecast = f.cost_final,
    profit_forecast = round(f.contract - f.cost_final, 2),
    profitability_forecast_pct = round((f.contract - f.cost_final) / NULLIF(f.contract, 0) * 100, 1),
    earned_value_contract = round(f.contract * f.pct, 2),
    ev_classic_evm = round(f.bac * f.pct, 2),
    cpi_classic_evm = round(f.bac * f.pct / NULLIF(f.ac, 0), 4),
    updated_at = now()
  FROM fin f WHERE m.project_id = f.project_id
  RETURNING 1
)
SELECT count(*)::int FROM upd;
$f$;

-- 3) єдина точка входу (тригери time_log/money_log/wr_weekly_snapshots і n8n викликають archi_recalc)
CREATE OR REPLACE FUNCTION public.archi_recalc(p_project text DEFAULT NULL::text)
 RETURNS integer LANGUAGE sql AS $f$
  SELECT public.archi_recalc_stages(p_project) + public.archi_recalc_visit(p_project);
$f$;
