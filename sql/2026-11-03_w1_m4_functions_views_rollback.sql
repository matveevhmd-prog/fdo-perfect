-- Відкат M4: повернути попередні визначення (виконувати в Supabase SQL Editor: потрібні DROP VIEW/FUNCTION).
-- 1) в'ю (залежності: weekly_progress → snapshot_history)
DROP VIEW IF EXISTS public.archi_weekly_progress;
DROP VIEW IF EXISTS public.archi_snapshot_history;
DROP VIEW IF EXISTS public.archi_report_today;
DROP VIEW IF EXISTS public.archi_plan_execution;
DROP VIEW IF EXISTS public.evm_classic_today;
DROP VIEW IF EXISTS public.project_metrics_live;
DROP VIEW IF EXISTS public.rates_coverage_check;
-- 2) нові функції
DROP FUNCTION IF EXISTS public.archi_recalc(uuid, text);
DROP FUNCTION IF EXISTS public.archi_recalc_stages(uuid, text);
DROP FUNCTION IF EXISTS public.archi_recalc_visit(uuid, text);
DROP FUNCTION IF EXISTS public.archi_acts_plan(uuid, text, date);
DROP FUNCTION IF EXISTS public.archi_snapshot_metrics(uuid, text, date, jsonb, jsonb);
DROP FUNCTION IF EXISTS public.archi_snapshot_evm(uuid, text, date, jsonb, jsonb);
DROP FUNCTION IF EXISTS public.evm_classic_at(uuid, text, date);
-- 3) старі визначення функцій (із живої бази 03.11.2026)
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
CREATE OR REPLACE FUNCTION public.archi_recalc(p_project text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE sql
AS $function$
  SELECT public.archi_recalc_stages(p_project) + public.archi_recalc_visit(p_project);
$function$;
CREATE OR REPLACE FUNCTION public.archi_recalc_trg()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF TG_OP IN ('INSERT','UPDATE') THEN PERFORM public.archi_recalc(NEW.project_id); END IF;
  IF TG_OP IN ('UPDATE','DELETE') AND (TG_OP = 'DELETE' OR OLD.project_id IS DISTINCT FROM NEW.project_id) THEN PERFORM public.archi_recalc(OLD.project_id); END IF;
  RETURN NULL;
END $function$;
CREATE OR REPLACE FUNCTION public.archi_acts_plan(p_project text, p_asof date)
 RETURNS TABLE(acts_due integer, acts_done integer, acts_plan_idx numeric)
 LANGUAGE sql
 STABLE
AS $function$
WITH d AS (
  SELECT p."сума_план" AS amt,
         EXISTS (SELECT 1 FROM public.money_log x
                 WHERE x.project_id = p.project_id AND x."стадія" = p."стадія" AND x."тип" = 'акт_підписаний'
                   AND x."статус" = 'confirmed' AND x."дата" <= p_asof) AS signed
  FROM public.payment_schedule p
  WHERE p.project_id = p_project AND p."подія" = 'акт' AND p."дата_план" <= p_asof
)
SELECT count(*)::int,
       (count(*) FILTER (WHERE signed))::int,
       CASE WHEN count(*) > 0 AND COALESCE(sum(amt), 0) > 0
            THEN round(COALESCE(sum(amt) FILTER (WHERE signed), 0) / sum(amt), 2) END
FROM d
$function$;
CREATE OR REPLACE FUNCTION public.archi_snapshot_metrics(p_project text, p_week date, p_rd jsonb, p_et jsonb)
 RETURNS TABLE(rent_plan_pct numeric, rent_forecast_pct numeric, eac_hours_pct numeric, cpi numeric, etc_plan_hours numeric, etc_fact_hours numeric, etc_forecast_hours numeric, etc_gap_hours numeric, etc_gap_signal text)
 LANGUAGE sql
 STABLE
AS $function$
  WITH m AS (
    SELECT * FROM public.project_metrics WHERE project_id = p_project AND COALESCE(contract_type, 'stages') = 'stages'
  ),
  st AS (SELECT unnest(ARRAY['МБР','ЕП','П','Р']) AS s),
  hrs AS (
    SELECT t."стадія" AS s, sum(t."години") AS h,
           sum(t."години" * COALESCE(r.razom_grn_god, m.real_rate_team_hour)) AS cost
      FROM public.time_log t CROSS JOIN m LEFT JOIN public.rates r ON r.posada = t."виконавець"
     WHERE t.project_id = p_project AND t."статус" = 'confirmed' AND t."дата" <= p_week + 6
     GROUP BY 1
  ),
  -- AC годин — лише 4 стадії (канон 29.10.2026); собівартість — усі години (F-02, без змін)
  tot AS (SELECT COALESCE(sum(h) FILTER (WHERE s IN ('МБР','ЕП','П','Р')), 0) AS act_h, COALESCE(sum(cost), 0) AS team_cost FROM hrs),
  sub AS (
    SELECT COALESCE(sum("сума"), 0) AS sub_paid FROM public.money_log
     WHERE project_id = p_project AND "статус" = 'confirmed' AND "тип" = 'оплата_субпідряднику' AND "дата" <= p_week + 6
  ),
  ps AS (
    SELECT st.s, COALESCE((m.etc_plan_by_stage ->> st.s)::numeric, 0) AS plan_h,
           COALESCE((p_et ->> st.s)::numeric,
                    CASE WHEN (p_rd ->> st.s)::numeric >= 100 OR (m.etc_plan_by_stage IS NOT NULL AND COALESCE((m.etc_plan_by_stage ->> st.s)::numeric, 0) = 0) THEN 0 END) AS etc_f,
           COALESCE((p_rd ->> st.s)::numeric,
                    CASE WHEN m.etc_plan_by_stage IS NOT NULL AND COALESCE((m.etc_plan_by_stage ->> st.s)::numeric, 0) = 0 THEN 100 END) AS rd_f
      FROM m CROSS JOIN st
  ),
  agg AS (
    SELECT CASE WHEN count(etc_f) = 4 THEN sum(etc_f) END AS etc_total,
           CASE WHEN count(rd_f) = 4 AND sum(plan_h) > 0 THEN sum(rd_f / 100 * plan_h) / sum(plan_h) END AS pct_complete,
           sum(plan_h) AS plan_all
      FROM ps
  ),
  f AS (
    SELECT m.profitability_plan_pct AS rpp, m.contract_amount, m.bac, m.real_rate_team_hour AS rate,
           GREATEST(COALESCE(m.cost_plan_subcontract, 0) - sub.sub_paid, 0) AS mtc_sub,
           round(tot.team_cost + sub.sub_paid, 2) AS actual_cost, tot.act_h, agg.etc_total, agg.pct_complete, agg.plan_all,
           CASE WHEN agg.plan_all IS NOT NULL THEN round(agg.plan_all - tot.act_h, 1) END AS etc_fact
      FROM m CROSS JOIN tot CROSS JOIN sub CROSS JOIN agg
  )
  SELECT f.rpp,
         round((f.contract_amount - round(f.actual_cost + f.etc_total * f.rate + f.mtc_sub, 2)) / NULLIF(f.contract_amount, 0) * 100, 1),
         CASE WHEN COALESCE(f.plan_all, 0) > 0 AND f.etc_total IS NOT NULL THEN round((f.act_h + f.etc_total) / f.plan_all * 1000) / 10 END,
         round(round(f.bac * f.pct_complete, 2) / NULLIF(f.actual_cost, 0), 4),
         f.plan_all,
         f.etc_fact,
         f.etc_total,
         CASE WHEN f.etc_total IS NOT NULL AND f.etc_fact IS NOT NULL THEN round(f.etc_total - f.etc_fact, 1) END,
         public.archi_etc_gap_signal(f.etc_fact, f.etc_total)
    FROM f;
$function$;
CREATE OR REPLACE FUNCTION public.archi_snapshot_evm(p_project text, p_week date, p_rd jsonb, p_et jsonb)
 RETURNS TABLE(spent_pct numeric, ready_pm_pct numeric, ready_fc_pct numeric, ready_gap_pp numeric, ready_gap_signal text, eff_hours_idx numeric, eff_signal text, acts_to_ev numeric, paid_to_acts numeric)
 LANGUAGE sql
 STABLE
AS $function$
  WITH m AS (
    SELECT * FROM public.project_metrics WHERE project_id = p_project AND COALESCE(contract_type, 'stages') = 'stages'
  ),
  st AS (SELECT unnest(ARRAY['МБР','ЕП','П','Р']) AS s),
  -- AC годин — лише 4 стадії (канон 29.10.2026)
  tot AS (
    SELECT COALESCE(sum(t."години"), 0) AS act_h FROM public.time_log t
     WHERE t.project_id = p_project AND t."статус" = 'confirmed' AND t."дата" <= p_week + 6
       AND t."стадія" IN ('МБР','ЕП','П','Р')
  ),
  mon AS (
    SELECT COALESCE(sum("сума") FILTER (WHERE "тип" = 'акт_підписаний'), 0) AS acts,
           COALESCE(sum("сума") FILTER (WHERE "тип" = 'надходження_від_замовника'), 0) AS received
      FROM public.money_log WHERE project_id = p_project AND "статус" = 'confirmed' AND "дата" <= p_week + 6
  ),
  ps AS (
    SELECT st.s, COALESCE((m.etc_plan_by_stage ->> st.s)::numeric, 0) AS plan_h,
           COALESCE((p_et ->> st.s)::numeric,
                    CASE WHEN (p_rd ->> st.s)::numeric >= 100 OR (m.etc_plan_by_stage IS NOT NULL AND COALESCE((m.etc_plan_by_stage ->> st.s)::numeric, 0) = 0) THEN 0 END) AS etc_f,
           COALESCE((p_rd ->> st.s)::numeric,
                    CASE WHEN m.etc_plan_by_stage IS NOT NULL AND COALESCE((m.etc_plan_by_stage ->> st.s)::numeric, 0) = 0 THEN 100 END) AS rd_f
      FROM m CROSS JOIN st
  ),
  agg AS (
    SELECT CASE WHEN count(etc_f) = 4 THEN sum(etc_f) END AS etc_total,
           CASE WHEN count(rd_f) = 4 AND sum(plan_h) > 0 THEN sum(rd_f / 100 * plan_h) / sum(plan_h) END AS pct_complete,
           sum(plan_h) AS plan_all
      FROM ps
  ),
  g AS (
    SELECT agg.plan_all, m.contract_amount, tot.act_h, agg.etc_total, agg.pct_complete, mon.acts, mon.received,
           CASE WHEN COALESCE(agg.plan_all, 0) > 0 THEN round(100 * tot.act_h / agg.plan_all, 1) END AS spent_pct,
           CASE WHEN agg.pct_complete IS NOT NULL THEN round(100 * agg.pct_complete, 1) END AS ready_pm_pct,
           CASE WHEN agg.etc_total IS NOT NULL AND tot.act_h + agg.etc_total > 0 THEN round(100 * tot.act_h / (tot.act_h + agg.etc_total), 1) END AS ready_fc_pct,
           CASE WHEN COALESCE(agg.plan_all, 0) > 0 AND agg.etc_total IS NOT NULL AND tot.act_h + agg.etc_total > 0 THEN round(agg.plan_all / (tot.act_h + agg.etc_total), 2) END AS eff_idx
      FROM m CROSS JOIN tot CROSS JOIN mon CROSS JOIN agg
  )
  SELECT g.spent_pct, g.ready_pm_pct, g.ready_fc_pct,
         CASE WHEN g.ready_pm_pct IS NOT NULL AND g.ready_fc_pct IS NOT NULL THEN round(g.ready_pm_pct - g.ready_fc_pct, 1) END,
         public.archi_ready_gap_signal(CASE WHEN g.ready_pm_pct IS NOT NULL AND g.ready_fc_pct IS NOT NULL THEN round(g.ready_pm_pct - g.ready_fc_pct, 1) END),
         g.eff_idx, public.archi_idx_signal(g.eff_idx),
         CASE WHEN g.pct_complete IS NOT NULL AND g.contract_amount > 0 AND g.pct_complete > 0 THEN round(g.acts / (g.contract_amount * g.pct_complete), 2) END,
         CASE WHEN g.acts > 0 THEN round(g.received / g.acts, 2) END
    FROM g;
$function$;
CREATE OR REPLACE FUNCTION public.evm_classic_at(p_project text, p_t date)
 RETURNS TABLE(project_id text, as_of date, has_baseline boolean, baseline_no integer, packages integer, bac numeric, pv numeric, ev numeric, ac numeric, cv numeric, sv numeric, cpi numeric, spi numeric, eac numeric, etc numeric, vac numeric, tcpi numeric)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
WITH pr AS (
  SELECT m.project_id, m.real_rate_team_hour FROM public.project_metrics m
  WHERE COALESCE(m.contract_type, 'stages') = 'stages' AND (p_project IS NULL OR m.project_id = p_project)),
cur AS (
  SELECT p.project_id, max(p.baseline_no) AS bn FROM public.evm_packages p
  JOIN pr ON pr.project_id = p.project_id GROUP BY p.project_id),
pk AS (
  SELECT p.* FROM public.evm_packages p JOIN cur c ON c.project_id = p.project_id AND c.bn = p.baseline_no),
last_ev AS (
  SELECT DISTINCT ON (d.package_id) d.package_id, d.event
  FROM public.evm_package_done d JOIN pk ON pk.id = d.package_id
  WHERE d.event IN ('done', 'cancelled') AND d.event_date <= p_t
  ORDER BY d.package_id, d.event_date DESC, d.id DESC),
agg AS (
  SELECT pk.project_id, count(*)::int AS n, sum(pk.budget_uah) AS bac_v,
         sum(pk.budget_uah) FILTER (WHERE pk.planned_finish <= p_t) AS pv_v,
         sum(pk.budget_uah) FILTER (WHERE le.event = 'done') AS ev_v
  FROM pk LEFT JOIN last_ev le ON le.package_id = pk.id GROUP BY pk.project_id),
hrs AS (
  SELECT t.project_id, sum(t."години" * COALESCE(r.razom_grn_god, pr.real_rate_team_hour)) AS c
  FROM public.time_log t JOIN pr ON pr.project_id = t.project_id
  LEFT JOIN public.rates r ON r.posada = t."виконавець"
  WHERE t."статус" = 'confirmed' AND t."стадія" IN ('МБР', 'ЕП', 'П', 'Р') AND t."дата" <= p_t
  GROUP BY t.project_id),
sub AS (
  SELECT mo.project_id, sum(mo."сума") AS c FROM public.money_log mo JOIN pr ON pr.project_id = mo.project_id
  WHERE mo."статус" = 'confirmed' AND mo."тип" = 'оплата_субпідряднику' AND mo."дата" <= p_t
  GROUP BY mo.project_id),
base AS (
  SELECT pr.project_id, (a.project_id IS NOT NULL) AS hb, c.bn, a.n, a.bac_v,
         COALESCE(a.pv_v, 0) AS pv_v, COALESCE(a.ev_v, 0) AS ev_v,
         COALESCE(h.c, 0) + COALESCE(s.c, 0) AS ac_v
  FROM pr
  LEFT JOIN agg a ON a.project_id = pr.project_id
  LEFT JOIN cur c ON c.project_id = pr.project_id
  LEFT JOIN hrs h ON h.project_id = pr.project_id
  LEFT JOIN sub s ON s.project_id = pr.project_id)
SELECT b.project_id, p_t, b.hb, b.bn, b.n,
       b.bac_v,
       CASE WHEN b.hb THEN b.pv_v END, CASE WHEN b.hb THEN b.ev_v END, CASE WHEN b.hb THEN b.ac_v END,
       i.cv, i.sv, i.cpi, i.spi, i.eac, i.etc, i.vac, i.tcpi
FROM base b
LEFT JOIN LATERAL public.evm_classic_indices(b.bac_v, b.pv_v, b.ev_v, b.ac_v) i ON b.hb
ORDER BY b.project_id;
$function$;
-- 4) старі в'ю (порядок: snapshot_history перед weekly_progress)
CREATE VIEW public.archi_snapshot_history AS
SELECT s.project_id,
    s.week_start,
    x.rent_plan_pct,
    x.rent_forecast_pct,
    x.eac_hours_pct,
    x.cpi,
    x.etc_plan_hours,
    x.etc_fact_hours,
    x.etc_forecast_hours,
    x.etc_gap_hours,
    archi_vac_signal(x.etc_gap_hours, x.etc_plan_hours) AS etc_gap_signal,
    e.spent_pct,
    e.ready_pm_pct,
    e.ready_fc_pct,
    e.ready_gap_pp,
    e.ready_gap_signal,
    e.eff_hours_idx,
    e.eff_signal,
    e.acts_to_ev,
    e.paid_to_acts,
    NULL::text AS acts_to_ev_signal,
    archi_flow_idx_signal(e.paid_to_acts) AS paid_to_acts_signal,
        CASE
            WHEN e.spent_pct > 0::numeric AND e.ready_pm_pct IS NOT NULL THEN round(e.ready_pm_pct / e.spent_pct, 2)
            ELSE NULL::numeric
        END AS exec_idx,
    archi_flow_idx_signal(
        CASE
            WHEN e.spent_pct > 0::numeric AND e.ready_pm_pct IS NOT NULL THEN round(e.ready_pm_pct / e.spent_pct, 2)
            ELSE NULL::numeric
        END) AS exec_signal,
    a.acts_due,
    a.acts_done,
    a.acts_plan_idx,
    archi_flow_idx_signal(a.acts_plan_idx) AS acts_plan_signal
   FROM wr_weekly_snapshots s
     CROSS JOIN LATERAL archi_snapshot_metrics(s.project_id, s.week_start, s."готовність_pct", s."залишок_прогноз_по_стадіях") x(rent_plan_pct, rent_forecast_pct, eac_hours_pct, cpi, etc_plan_hours, etc_fact_hours, etc_forecast_hours, etc_gap_hours, etc_gap_signal)
     CROSS JOIN LATERAL archi_snapshot_evm(s.project_id, s.week_start, s."готовність_pct", s."залишок_прогноз_по_стадіях") e(spent_pct, ready_pm_pct, ready_fc_pct, ready_gap_pp, ready_gap_signal, eff_hours_idx, eff_signal, acts_to_ev, paid_to_acts)
     CROSS JOIN LATERAL archi_acts_plan(s.project_id, s.week_start + 6) a(acts_due, acts_done, acts_plan_idx);;
CREATE VIEW public.archi_weekly_progress AS
WITH h AS (
         SELECT archi_snapshot_history.project_id,
            archi_snapshot_history.week_start,
            archi_snapshot_history.ready_pm_pct,
            lag(archi_snapshot_history.week_start) OVER w AS prev_week,
            lag(archi_snapshot_history.ready_pm_pct) OVER w AS prev_ready
           FROM archi_snapshot_history
          WINDOW w AS (PARTITION BY archi_snapshot_history.project_id ORDER BY archi_snapshot_history.week_start)
        ), i AS (
         SELECT h.project_id,
            h.week_start,
            h.prev_week,
            h.prev_ready,
            h.ready_pm_pct AS ready,
            m.contract_amount,
            m.real_rate_team_hour AS rate0
           FROM h
             JOIN project_metrics m ON m.project_id = h.project_id
          WHERE h.prev_week IS NOT NULL AND h.ready_pm_pct IS NOT NULL AND h.prev_ready IS NOT NULL
        ), c AS (
         SELECT i.project_id,
            i.week_start,
            i.prev_week,
            i.prev_ready,
            i.ready,
            i.contract_amount,
            i.rate0,
            hrs.hours,
            hrs.cost
           FROM i
             LEFT JOIN LATERAL ( SELECT COALESCE(sum(t."години"), 0::numeric) AS hours,
                    COALESCE(sum(t."години" * COALESCE(r.razom_grn_god, i.rate0)), 0::numeric) AS cost
                   FROM time_log t
                     LEFT JOIN rates r ON r.posada = t."виконавець"
                  WHERE t.project_id = i.project_id AND t."статус" = 'confirmed'::text AND t."дата" > (i.prev_week + 6) AND t."дата" <= (i.week_start + 6)) hrs ON true
        )
 SELECT project_id,
    week_start,
    prev_week,
    round(prev_ready, 1) AS ready_prev_pct,
    round(ready, 1) AS ready_pct,
    round(ready - prev_ready, 1) AS d_ready_pp,
    round(hours, 1) AS hours,
    round(cost) AS cost_uah,
    contract_amount,
    round((ready - prev_ready) / 100::numeric * contract_amount) AS value_uah,
    round((ready - prev_ready) / 100::numeric * contract_amount - cost) AS result_uah,
        CASE
            WHEN cost > 0::numeric THEN round((ready - prev_ready) / 100::numeric * contract_amount / cost, 2)
            ELSE NULL::numeric
        END AS idx,
    archi_flow_idx_signal(
        CASE
            WHEN cost > 0::numeric THEN round((ready - prev_ready) / 100::numeric * contract_amount / cost, 2)
            ELSE NULL::numeric
        END) AS signal,
    round(GREATEST(ready - prev_ready, 0::numeric) / 100::numeric * contract_amount) AS budget_uah,
    round(LEAST(cost, GREATEST(ready - prev_ready, 0::numeric) / 100::numeric * contract_amount)) AS customer_money_uah,
    round(GREATEST(cost - GREATEST(ready - prev_ready, 0::numeric) / 100::numeric * contract_amount, 0::numeric)) AS owner_money_uah
   FROM c;;
CREATE VIEW public.archi_report_today AS
SELECT m.project_id,
    m.data_updated_at,
    m.profitability_plan_pct AS rent_plan_pct,
    m.profitability_forecast_pct AS rent_forecast_pct,
    m.planned_hours,
    m.actual_hours,
    ( SELECT sum(e.value::numeric) AS sum
           FROM jsonb_each_text(m.etc_plan_by_stage) e(key, value)
          WHERE e.key = ANY (ARRAY['МБР'::text, 'ЕП'::text, 'П'::text, 'Р'::text])) AS etc_plan_hours,
        CASE
            WHEN b.bac_h IS NOT NULL AND b.ac_h IS NOT NULL THEN round(b.bac_h - b.ac_h, 1)
            ELSE NULL::numeric
        END AS etc_fact_hours,
    m.etc_forecast_total_hours AS etc_forecast_hours,
        CASE
            WHEN COALESCE(b.bac_h, 0::numeric) > 0::numeric AND b.ac_h IS NOT NULL AND m.etc_forecast_total_hours IS NOT NULL THEN round((b.ac_h + m.etc_forecast_total_hours) / b.bac_h * 1000::numeric) / 10::numeric
            ELSE NULL::numeric
        END AS eac_hours_pct,
    m.cpi_classic_evm AS cpi,
    m.nearest_act_date AS act_date,
    m.nearest_act_probability AS act_prob,
    m.nearest_doc_deadline AS doc_date,
    m.doc_issuance_probability AS doc_prob,
        CASE
            WHEN b.bac_h IS NOT NULL AND b.ac_h IS NOT NULL AND m.etc_forecast_total_hours IS NOT NULL THEN round(m.etc_forecast_total_hours - round(b.bac_h - b.ac_h, 1), 1)
            ELSE NULL::numeric
        END AS etc_gap_hours,
    archi_vac_signal(
        CASE
            WHEN b.bac_h IS NOT NULL AND b.ac_h IS NOT NULL AND m.etc_forecast_total_hours IS NOT NULL THEN round(m.etc_forecast_total_hours - round(b.bac_h - b.ac_h, 1), 1)
            ELSE NULL::numeric
        END, b.bac_h) AS etc_gap_signal,
        CASE
            WHEN COALESCE(b.bac_h, 0::numeric) > 0::numeric AND b.ac_h IS NOT NULL THEN round(100::numeric * b.ac_h / b.bac_h, 1)
            ELSE NULL::numeric
        END AS spent_pct,
        CASE
            WHEN m.earned_value_contract IS NOT NULL AND COALESCE(m.contract_amount, 0::numeric) > 0::numeric THEN round(100::numeric * m.earned_value_contract / m.contract_amount, 1)
            ELSE NULL::numeric
        END AS ready_pm_pct,
        CASE
            WHEN m.etc_forecast_total_hours IS NOT NULL AND b.ac_h IS NOT NULL AND (b.ac_h + m.etc_forecast_total_hours) > 0::numeric THEN round(100::numeric * b.ac_h / (b.ac_h + m.etc_forecast_total_hours), 1)
            ELSE NULL::numeric
        END AS ready_fc_pct,
        CASE
            WHEN m.earned_value_contract IS NOT NULL AND COALESCE(m.contract_amount, 0::numeric) > 0::numeric AND m.etc_forecast_total_hours IS NOT NULL AND b.ac_h IS NOT NULL AND (b.ac_h + m.etc_forecast_total_hours) > 0::numeric THEN round(round(100::numeric * m.earned_value_contract / m.contract_amount, 1) - round(100::numeric * b.ac_h / (b.ac_h + m.etc_forecast_total_hours), 1), 1)
            ELSE NULL::numeric
        END AS ready_gap_pp,
    archi_ready_gap_signal(
        CASE
            WHEN m.earned_value_contract IS NOT NULL AND COALESCE(m.contract_amount, 0::numeric) > 0::numeric AND m.etc_forecast_total_hours IS NOT NULL AND b.ac_h IS NOT NULL AND (b.ac_h + m.etc_forecast_total_hours) > 0::numeric THEN round(round(100::numeric * m.earned_value_contract / m.contract_amount, 1) - round(100::numeric * b.ac_h / (b.ac_h + m.etc_forecast_total_hours), 1), 1)
            ELSE NULL::numeric
        END) AS ready_gap_signal,
        CASE
            WHEN COALESCE(b.bac_h, 0::numeric) > 0::numeric AND m.etc_forecast_total_hours IS NOT NULL AND b.ac_h IS NOT NULL AND (b.ac_h + m.etc_forecast_total_hours) > 0::numeric THEN round(b.bac_h / (b.ac_h + m.etc_forecast_total_hours), 2)
            ELSE NULL::numeric
        END AS eff_hours_idx,
    archi_idx_signal(
        CASE
            WHEN COALESCE(b.bac_h, 0::numeric) > 0::numeric AND m.etc_forecast_total_hours IS NOT NULL AND b.ac_h IS NOT NULL AND (b.ac_h + m.etc_forecast_total_hours) > 0::numeric THEN round(b.bac_h / (b.ac_h + m.etc_forecast_total_hours), 2)
            ELSE NULL::numeric
        END) AS eff_signal,
        CASE
            WHEN m.earned_value_contract > 0::numeric THEN round(m.acts_amount / m.earned_value_contract, 2)
            ELSE NULL::numeric
        END AS acts_to_ev,
        CASE
            WHEN m.acts_amount > 0::numeric THEN round(m.money_received / m.acts_amount, 2)
            ELSE NULL::numeric
        END AS paid_to_acts,
    NULL::text AS acts_to_ev_signal,
    archi_flow_idx_signal(
        CASE
            WHEN m.acts_amount > 0::numeric THEN round(m.money_received / m.acts_amount, 2)
            ELSE NULL::numeric
        END) AS paid_to_acts_signal,
        CASE
            WHEN COALESCE(b.bac_h, 0::numeric) > 0::numeric AND b.ac_h IS NOT NULL AND b.ac_h > 0::numeric AND m.earned_value_contract IS NOT NULL AND COALESCE(m.contract_amount, 0::numeric) > 0::numeric THEN round(round(100::numeric * m.earned_value_contract / m.contract_amount, 1) / NULLIF(round(100::numeric * b.ac_h / b.bac_h, 1), 0::numeric), 2)
            ELSE NULL::numeric
        END AS exec_idx,
    archi_flow_idx_signal(
        CASE
            WHEN COALESCE(b.bac_h, 0::numeric) > 0::numeric AND b.ac_h IS NOT NULL AND b.ac_h > 0::numeric AND m.earned_value_contract IS NOT NULL AND COALESCE(m.contract_amount, 0::numeric) > 0::numeric THEN round(round(100::numeric * m.earned_value_contract / m.contract_amount, 1) / NULLIF(round(100::numeric * b.ac_h / b.bac_h, 1), 0::numeric), 2)
            ELSE NULL::numeric
        END) AS exec_signal,
    a.acts_due,
    a.acts_done,
    a.acts_plan_idx,
    archi_flow_idx_signal(a.acts_plan_idx) AS acts_plan_signal,
        CASE
            WHEN COALESCE(b.bac_h, 0::numeric) > 0::numeric AND b.ac_h IS NOT NULL AND m.etc_forecast_total_hours IS NOT NULL THEN round(100::numeric * round(m.etc_forecast_total_hours - round(b.bac_h - b.ac_h, 1), 1) / b.bac_h, 1)
            ELSE NULL::numeric
        END AS etc_gap_pct_bac,
    ( SELECT jsonb_object_agg(s.key, archi_vac_signal(((s.value ->> 'etc_forecast_hours'::text)::numeric) - (((s.value ->> 'etc_plan_hours'::text)::numeric) - COALESCE((s.value ->> 'actual_hours_live'::text)::numeric, 0::numeric)), (s.value ->> 'etc_plan_hours'::text)::numeric)) AS jsonb_object_agg
           FROM jsonb_each(m.stage_data) s(key, value)
          WHERE (s.key = ANY (ARRAY['МБР'::text, 'ЕП'::text, 'П'::text, 'Р'::text])) AND (s.value ->> 'etc_forecast_hours'::text) IS NOT NULL AND COALESCE((s.value ->> 'etc_plan_hours'::text)::numeric, 0::numeric) > 0::numeric) AS stage_etc_signal
   FROM project_metrics m
     CROSS JOIN LATERAL ( SELECT
                CASE
                    WHEN COALESCE(m.contract_type, 'stages'::text) = 'stages'::text THEN ( SELECT sum(e.value::numeric) AS sum
                       FROM jsonb_each_text(m.etc_plan_by_stage) e(key, value)
                      WHERE e.key = ANY (ARRAY['МБР'::text, 'ЕП'::text, 'П'::text, 'Р'::text]))
                    ELSE m.planned_hours
                END AS bac_h,
                CASE
                    WHEN COALESCE(m.contract_type, 'stages'::text) = 'stages'::text THEN ( SELECT COALESCE(sum(t."години"), 0::numeric) AS "coalesce"
                       FROM time_log t
                      WHERE t.project_id = m.project_id AND t."статус" = 'confirmed'::text AND (t."стадія" = ANY (ARRAY['МБР'::text, 'ЕП'::text, 'П'::text, 'Р'::text])))
                    ELSE m.actual_hours
                END AS ac_h) b
     CROSS JOIN LATERAL archi_acts_plan(m.project_id, COALESCE((m.data_updated_at AT TIME ZONE 'Europe/Kyiv'::text)::date, CURRENT_DATE)) a(acts_due, acts_done, acts_plan_idx);;
CREATE VIEW public.archi_plan_execution AS
WITH c AS (
         SELECT p.project_id,
            p.week_start,
            count(*)::integer AS total,
            count(*) FILTER (WHERE p.status = 'done'::text)::integer AS done,
            count(*) FILTER (WHERE p.status = 'not_done'::text)::integer AS not_done,
            count(*) FILTER (WHERE p.status = 'no_answer'::text)::integer AS no_answer,
            count(*) FILTER (WHERE p.status <> ALL (ARRAY['done'::text, 'not_done'::text, 'no_answer'::text]))::integer AS pending,
            max(p.carry_count) AS max_carry
           FROM wr_plan_items p
          GROUP BY p.project_id, p.week_start
        ), t AS (
         SELECT COALESCE(( SELECT archi_thresholds.value
                   FROM archi_thresholds
                  WHERE archi_thresholds.key = 'plan_exec_red'::text), 50::numeric) AS red,
            COALESCE(( SELECT archi_thresholds.value
                   FROM archi_thresholds
                  WHERE archi_thresholds.key = 'plan_exec_yellow'::text), 70::numeric) AS yellow
        )
 SELECT c.project_id,
    c.week_start,
    c.total,
    c.done,
    c.not_done,
    c.no_answer,
    c.pending,
    c.max_carry,
        CASE
            WHEN c.pending = 0 AND c.total > 0 THEN round(100.0 * c.done::numeric / c.total::numeric)
            ELSE NULL::numeric
        END AS exec_pct,
        CASE
            WHEN c.pending = 0 AND c.total > 0 THEN
            CASE
                WHEN round(100.0 * c.done::numeric / c.total::numeric) < t.red THEN 'red'::text
                WHEN round(100.0 * c.done::numeric / c.total::numeric) < t.yellow THEN 'yellow'::text
                ELSE 'green'::text
            END
            ELSE NULL::text
        END AS signal
   FROM c
     CROSS JOIN t;;
CREATE VIEW public.evm_classic_today WITH (security_invoker = true) AS
SELECT project_id,
    as_of,
    has_baseline,
    baseline_no,
    packages,
    bac,
    pv,
    ev,
    ac,
    cv,
    sv,
    cpi,
    spi,
    eac,
    etc,
    vac,
    tcpi
   FROM evm_classic_at(NULL::text, date_trunc('week'::text, timezone('Europe/Kyiv'::text, now()))::date + 6) evm_classic_at(project_id, as_of, has_baseline, baseline_no, packages, bac, pv, ev, ac, cv, sv, cpi, spi, eac, etc, vac, tcpi);;
CREATE VIEW public.project_metrics_live AS
SELECT pm.project_id,
    pm.contract_amount,
    pm.planned_hours,
    COALESCE(th.actual_hours, 0::numeric) AS actual_hours,
    round(COALESCE(th.actual_hours, 0::numeric) / NULLIF(pm.planned_hours, 0::numeric) * 100::numeric, 2) AS percent_execution,
    round(pm.contract_amount * COALESCE(th.actual_hours, 0::numeric) / NULLIF(pm.planned_hours, 0::numeric), 2) AS earned_value_contract,
    round(COALESCE(tc.team_cost, 0::numeric) + COALESCE(mc.subcontract_cost, 0::numeric), 2) AS actual_cost,
    round(pm.contract_amount * COALESCE(th.actual_hours, 0::numeric) / NULLIF(pm.planned_hours, 0::numeric) / NULLIF(COALESCE(tc.team_cost, 0::numeric) + COALESCE(mc.subcontract_cost, 0::numeric), 0::numeric), 4) AS efficiency_contract,
    round(pm.contract_amount * COALESCE(th.actual_hours, 0::numeric) / NULLIF(pm.planned_hours, 0::numeric) - (COALESCE(tc.team_cost, 0::numeric) + COALESCE(mc.subcontract_cost, 0::numeric)), 2) AS comparison
   FROM project_metrics pm
     LEFT JOIN ( SELECT time_log.project_id,
            sum(time_log."години") AS actual_hours
           FROM time_log
          WHERE time_log."статус" = 'confirmed'::text
          GROUP BY time_log.project_id) th ON th.project_id = pm.project_id
     LEFT JOIN ( SELECT t.project_id,
            sum(t."години" * r.razom_grn_god) AS team_cost
           FROM time_log t
             JOIN rates r ON r.posada = t."виконавець"
          WHERE t."статус" = 'confirmed'::text
          GROUP BY t.project_id) tc ON tc.project_id = pm.project_id
     LEFT JOIN ( SELECT money_log.project_id,
            sum(money_log."сума") AS subcontract_cost
           FROM money_log
          WHERE money_log."тип" = 'оплата_субпідряднику'::text AND money_log."статус" = 'confirmed'::text
          GROUP BY money_log.project_id) mc ON mc.project_id = pm.project_id;;
CREATE VIEW public.rates_coverage_check AS
SELECT DISTINCT t.project_id,
    t."виконавець" AS posada_bez_stavky
   FROM time_log t
     LEFT JOIN rates r ON r.posada = t."виконавець"
  WHERE t."статус" = 'confirmed'::text AND r.posada IS NULL;;
