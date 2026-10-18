-- 18.10.2026 · project_metrics.data_updated_at — дата оновлення даних проєкту (TECH_SPEC §8.1, FORMULAS D-13)
-- Єдине місце обчислення: archi_recalc_stages / archi_recalc_visit.
-- data_updated_at = найпізніший час надходження вхідних даних проєкту:
--   time_log і money_log лише зі статусом 'confirmed' (як і в розрахунках), усі знімки звіту ПМа,
--   графік оплат (payment_schedule.baseline_at), план (project_metrics.baseline_at).
-- Залежить лише від вхідних даних: повторний перерахунок значення не змінює (на відміну від updated_at).
-- Відкат: попередні версії функцій — sql/2026-10-17_visit_contracts.sql; колонку можна лишити.

ALTER TABLE public.project_metrics ADD COLUMN IF NOT EXISTS data_updated_at timestamptz;

CREATE OR REPLACE FUNCTION public.archi_recalc_stages(p_project text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE sql
AS $function$
WITH pm AS (
  SELECT * FROM public.project_metrics WHERE COALESCE(contract_type, 'stages') = 'stages' AND (p_project IS NULL OR project_id = p_project)
),
st AS (SELECT unnest(ARRAY['МБР','ЕП','П','Р']) AS s),
hrs AS (
  SELECT t.project_id, t."стадія" AS s, sum(t."години") AS h,
         sum(t."години" * COALESCE(r.razom_grn_god, m.real_rate_team_hour)) AS cost
  FROM public.time_log t JOIN pm m ON m.project_id = t.project_id
  LEFT JOIN public.rates r ON r.posada = t."виконавець"
  WHERE t."статус" = 'confirmed' GROUP BY 1, 2
),
money AS (
  SELECT project_id,
         sum("сума") FILTER (WHERE "тип" = 'оплата_субпідряднику') AS sub_paid,
         sum("сума") FILTER (WHERE "тип" = 'акт_підписаний') AS acts,
         sum("сума") FILTER (WHERE "тип" = 'надходження_від_замовника') AS received
  FROM public.money_log WHERE "статус" = 'confirmed' GROUP BY 1
),
snap AS (
  SELECT DISTINCT ON (project_id) project_id, week_start AS wk, "готовність_pct" AS rd, "залишок_прогноз_по_стадіях" AS et, "ймовірність_документації" AS docp
  FROM public.wr_weekly_snapshots ORDER BY project_id, week_start DESC
),
src AS (
  SELECT project_id, max(ts) AS ts FROM (
    SELECT project_id, created_at AS ts FROM public.time_log WHERE "статус" = 'confirmed'
    UNION ALL SELECT project_id, created_at FROM public.money_log WHERE "статус" = 'confirmed'
    UNION ALL SELECT project_id, created_at FROM public.wr_weekly_snapshots
    UNION ALL SELECT project_id, baseline_at FROM public.payment_schedule
    UNION ALL SELECT project_id, baseline_at FROM public.project_metrics
  ) u GROUP BY 1
),
per_stage AS (
  SELECT m.project_id, st.s, COALESCE((m.etc_plan_by_stage ->> st.s)::numeric, 0) AS plan_h, COALESCE(h.h, 0) AS act_h,
         -- ETC_прогноз тільки від ПМа; стадія з готовністю 100% = 0 автоматично; інакше NULL (плановий залишок НЕ підставляється)
         COALESCE((sn.et ->> st.s)::numeric, CASE WHEN (sn.rd ->> st.s)::numeric >= 100 OR (m.etc_plan_by_stage IS NOT NULL AND COALESCE((m.etc_plan_by_stage ->> st.s)::numeric, 0) = 0) THEN 0 END) AS etc_f,
         COALESCE((sn.rd ->> st.s)::numeric, CASE WHEN m.etc_plan_by_stage IS NOT NULL AND COALESCE((m.etc_plan_by_stage ->> st.s)::numeric, 0) = 0 THEN 100 END) AS rd_f
  FROM pm m CROSS JOIN st
  LEFT JOIN hrs h ON h.project_id = m.project_id AND h.s = st.s
  LEFT JOIN snap sn ON sn.project_id = m.project_id
),
agg AS (
  SELECT project_id, sum(etc_f) AS etc_total, count(etc_f) AS etc_n,
         CASE WHEN count(rd_f) = 4 AND sum(plan_h) > 0 THEN sum(rd_f / 100 * plan_h) / sum(plan_h) END AS pct_complete,
         jsonb_object_agg(s, jsonb_build_object('actual_hours_live', round(act_h, 2), 'etc_plan_hours', plan_h, 'etc_forecast_hours', etc_f, 'readiness_forecast', rd_f)) AS stage_data
  FROM per_stage GROUP BY 1
),
tot AS (SELECT project_id, sum(h) AS act_h, sum(cost) AS team_cost FROM hrs GROUP BY 1),
next_act AS (
  SELECT DISTINCT ON (p.project_id) p.project_id, p."дата_план" AS d, p."ймовірність_план" AS pr
  FROM public.payment_schedule p JOIN pm m ON m.project_id = p.project_id
  WHERE p."подія" = 'акт' AND NOT EXISTS (SELECT 1 FROM public.money_log x WHERE x.project_id = p.project_id AND x."стадія" = p."стадія" AND x."тип" = 'акт_підписаний' AND x."статус" = 'confirmed')
  ORDER BY p.project_id, p."дата_план"
),
next_doc AS (
  SELECT DISTINCT ON (p.project_id) p.project_id, p."дата_план" AS d, p."ймовірність_план" AS pr
  FROM public.payment_schedule p JOIN pm m ON m.project_id = p.project_id
  LEFT JOIN snap sn ON sn.project_id = p.project_id
  WHERE p."подія" = 'документація' AND COALESCE((sn.rd ->> p."стадія")::numeric, 0) < 100
  ORDER BY p.project_id, p."дата_план"
),
calc AS (
  SELECT m.project_id, COALESCE(t.act_h, 0) AS actual_hours,
         round(COALESCE(t.team_cost, 0) + COALESCE(mo.sub_paid, 0), 2) AS actual_cost,
         GREATEST(COALESCE(m.cost_plan_subcontract, 0) - COALESCE(mo.sub_paid, 0), 0) AS mtc_sub,
         -- ETC: оцінка ПМа по 4 стадіях. Якщо хоч по одній немає (і вона не завершена на 100%) — NULL, прогноз не рахується (рішення власника 10.10.2026)
         CASE WHEN a.etc_n = 4 THEN a.etc_total END AS etc_total,
         a.pct_complete, a.stage_data, sn.wk AS snap_week,
         COALESCE(mo.acts, 0) AS acts_amount, COALESCE(mo.received, 0) AS money_received,
         na.d AS nearest_act_date, na.pr AS nearest_act_probability,
         nd.d AS nearest_doc_deadline, COALESCE(sn.docp, nd.pr) AS doc_issuance_probability,
         m.contract_amount, m.bac, m.planned_hours, m.real_rate_team_hour,
         sr.ts AS data_updated_at
  FROM pm m
  LEFT JOIN tot t ON t.project_id = m.project_id
  LEFT JOIN money mo ON mo.project_id = m.project_id
  LEFT JOIN agg a ON a.project_id = m.project_id
  LEFT JOIN snap sn ON sn.project_id = m.project_id
  LEFT JOIN src sr ON sr.project_id = m.project_id
  LEFT JOIN next_act na ON na.project_id = m.project_id
  LEFT JOIN next_doc nd ON nd.project_id = m.project_id
),
fin AS (
  SELECT c.*,
         round(c.etc_total * c.real_rate_team_hour, 2) AS mtc_team,
         round(c.actual_cost + c.etc_total * c.real_rate_team_hour + c.mtc_sub, 2) AS cost_final,
         round(c.contract_amount * c.pct_complete, 2) AS ev_contract,
         round(c.bac * c.pct_complete, 2) AS ev_classic
  FROM calc c
),
upd AS (
  UPDATE public.project_metrics m SET
    actual_hours = f.actual_hours,
    hours_remaining = f.planned_hours - f.actual_hours,
    percent_execution = round(f.actual_hours / NULLIF(f.planned_hours, 0) * 100, 1),
    actual_cost = f.actual_cost,
    money_to_completion_subcontract = f.mtc_sub,
    etc_forecast_total_hours = f.etc_total,
    stage_data = f.stage_data,
    money_to_completion_team = f.mtc_team,
    cost_final_forecast = f.cost_final,
    profit_forecast = round(f.contract_amount - f.cost_final, 2),
    profitability_forecast_pct = round((f.contract_amount - f.cost_final) / NULLIF(f.contract_amount, 0) * 100, 1),
    forecast_confirmed_pct = COALESCE(round((f.contract_amount - f.cost_final) / NULLIF(f.contract_amount, 0) * 100, 1), m.forecast_confirmed_pct),
    forecast_confirmed_week = CASE WHEN round((f.contract_amount - f.cost_final) / NULLIF(f.contract_amount, 0) * 100, 1) IS NOT NULL THEN f.snap_week ELSE m.forecast_confirmed_week END,
    earned_value_contract = f.ev_contract,
    ev_classic_evm = f.ev_classic,
    cpi_classic_evm = round(f.ev_classic / NULLIF(f.actual_cost, 0), 4),
    acts_amount = f.acts_amount,
    money_received = f.money_received,
    nearest_act_date = f.nearest_act_date,
    nearest_act_probability = f.nearest_act_probability,
    nearest_doc_deadline = f.nearest_doc_deadline,
    doc_issuance_probability = f.doc_issuance_probability,
    data_updated_at = f.data_updated_at,
    updated_at = now()
  FROM fin f WHERE m.project_id = f.project_id
  RETURNING 1
)
SELECT count(*)::int FROM upd;
$function$;

CREATE OR REPLACE FUNCTION public.archi_recalc_visit(p_project text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE sql
AS $function$
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
src AS (
  SELECT project_id, max(ts) AS ts FROM (
    SELECT project_id, created_at AS ts FROM public.time_log WHERE "статус" = 'confirmed'
    UNION ALL SELECT project_id, created_at FROM public.money_log WHERE "статус" = 'confirmed'
    UNION ALL SELECT project_id, baseline_at FROM public.project_metrics
  ) u GROUP BY 1
),
calc AS (
  SELECT m.project_id, COALESCE(h.h, 0) AS ah,
         round(COALESCE(h.cost, 0) + COALESCE(mo.sub_paid, 0), 2) AS ac,
         COALESCE(mo.acts, 0) AS acts, COALESCE(mo.received, 0) AS rec,
         LEAST(COALESCE(mo.visits, 0), m.visits_plan)::int AS vd,
         m.visits_plan, m.visit_hours, m.real_rate_team_hour AS rate, m.bac,
         m.visits_plan * m.visit_price AS contract,
         sr.ts AS data_updated_at
  FROM pm m LEFT JOIN hrs h ON h.project_id = m.project_id LEFT JOIN money mo ON mo.project_id = m.project_id
  LEFT JOIN src sr ON sr.project_id = m.project_id
),
fin AS (
  SELECT c.*, (c.visits_plan - c.vd) * c.visit_hours AS etc,
         round(c.ac + (c.visits_plan - c.vd) * c.visit_hours * c.rate, 2) AS cost_final,
         c.vd::numeric / NULLIF(c.visits_plan, 0) AS pct
  FROM calc c
),
upd AS (
  UPDATE public.project_metrics m SET
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
    data_updated_at = f.data_updated_at,
    updated_at = now()
  FROM fin f WHERE m.project_id = f.project_id
  RETURNING 1
)
SELECT count(*)::int FROM upd;
$function$;
