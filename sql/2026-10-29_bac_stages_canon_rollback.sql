-- ВІДКАТ sql/2026-10-29_bac_stages_canon.sql: живі визначення до міграції (pg_get_viewdef / pg_get_functiondef, 29.10.2026).
CREATE OR REPLACE VIEW public.archi_report_today AS
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
            WHEN m.planned_hours IS NOT NULL AND m.actual_hours IS NOT NULL THEN round(m.planned_hours - m.actual_hours, 1)
            ELSE NULL::numeric
        END AS etc_fact_hours,
    m.etc_forecast_total_hours AS etc_forecast_hours,
        CASE
            WHEN COALESCE(m.planned_hours, 0::numeric) > 0::numeric AND m.actual_hours IS NOT NULL AND m.etc_forecast_total_hours IS NOT NULL THEN round((m.actual_hours + m.etc_forecast_total_hours) / m.planned_hours * 1000::numeric) / 10::numeric
            ELSE NULL::numeric
        END AS eac_hours_pct,
    m.cpi_classic_evm AS cpi,
    m.nearest_act_date AS act_date,
    m.nearest_act_probability AS act_prob,
    m.nearest_doc_deadline AS doc_date,
    m.doc_issuance_probability AS doc_prob,
        CASE
            WHEN m.planned_hours IS NOT NULL AND m.actual_hours IS NOT NULL AND m.etc_forecast_total_hours IS NOT NULL THEN round(m.etc_forecast_total_hours - round(m.planned_hours - m.actual_hours, 1), 1)
            ELSE NULL::numeric
        END AS etc_gap_hours,
    archi_vac_signal(
        CASE
            WHEN m.planned_hours IS NOT NULL AND m.actual_hours IS NOT NULL AND m.etc_forecast_total_hours IS NOT NULL THEN round(m.etc_forecast_total_hours - round(m.planned_hours - m.actual_hours, 1), 1)
            ELSE NULL::numeric
        END, m.planned_hours) AS etc_gap_signal,
        CASE
            WHEN COALESCE(m.planned_hours, 0::numeric) > 0::numeric AND m.actual_hours IS NOT NULL THEN round(100::numeric * m.actual_hours / m.planned_hours, 1)
            ELSE NULL::numeric
        END AS spent_pct,
        CASE
            WHEN m.earned_value_contract IS NOT NULL AND COALESCE(m.contract_amount, 0::numeric) > 0::numeric THEN round(100::numeric * m.earned_value_contract / m.contract_amount, 1)
            ELSE NULL::numeric
        END AS ready_pm_pct,
        CASE
            WHEN m.etc_forecast_total_hours IS NOT NULL AND m.actual_hours IS NOT NULL AND (m.actual_hours + m.etc_forecast_total_hours) > 0::numeric THEN round(100::numeric * m.actual_hours / (m.actual_hours + m.etc_forecast_total_hours), 1)
            ELSE NULL::numeric
        END AS ready_fc_pct,
        CASE
            WHEN m.earned_value_contract IS NOT NULL AND COALESCE(m.contract_amount, 0::numeric) > 0::numeric AND m.etc_forecast_total_hours IS NOT NULL AND m.actual_hours IS NOT NULL AND (m.actual_hours + m.etc_forecast_total_hours) > 0::numeric THEN round(round(100::numeric * m.earned_value_contract / m.contract_amount, 1) - round(100::numeric * m.actual_hours / (m.actual_hours + m.etc_forecast_total_hours), 1), 1)
            ELSE NULL::numeric
        END AS ready_gap_pp,
    archi_ready_gap_signal(
        CASE
            WHEN m.earned_value_contract IS NOT NULL AND COALESCE(m.contract_amount, 0::numeric) > 0::numeric AND m.etc_forecast_total_hours IS NOT NULL AND m.actual_hours IS NOT NULL AND (m.actual_hours + m.etc_forecast_total_hours) > 0::numeric THEN round(round(100::numeric * m.earned_value_contract / m.contract_amount, 1) - round(100::numeric * m.actual_hours / (m.actual_hours + m.etc_forecast_total_hours), 1), 1)
            ELSE NULL::numeric
        END) AS ready_gap_signal,
        CASE
            WHEN COALESCE(m.planned_hours, 0::numeric) > 0::numeric AND m.etc_forecast_total_hours IS NOT NULL AND m.actual_hours IS NOT NULL AND (m.actual_hours + m.etc_forecast_total_hours) > 0::numeric THEN round(m.planned_hours / (m.actual_hours + m.etc_forecast_total_hours), 2)
            ELSE NULL::numeric
        END AS eff_hours_idx,
    archi_idx_signal(
        CASE
            WHEN COALESCE(m.planned_hours, 0::numeric) > 0::numeric AND m.etc_forecast_total_hours IS NOT NULL AND m.actual_hours IS NOT NULL AND (m.actual_hours + m.etc_forecast_total_hours) > 0::numeric THEN round(m.planned_hours / (m.actual_hours + m.etc_forecast_total_hours), 2)
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
            WHEN COALESCE(m.planned_hours, 0::numeric) > 0::numeric AND m.actual_hours IS NOT NULL AND m.actual_hours > 0::numeric AND m.earned_value_contract IS NOT NULL AND COALESCE(m.contract_amount, 0::numeric) > 0::numeric THEN round(round(100::numeric * m.earned_value_contract / m.contract_amount, 1) / NULLIF(round(100::numeric * m.actual_hours / m.planned_hours, 1), 0::numeric), 2)
            ELSE NULL::numeric
        END AS exec_idx,
    archi_flow_idx_signal(
        CASE
            WHEN COALESCE(m.planned_hours, 0::numeric) > 0::numeric AND m.actual_hours IS NOT NULL AND m.actual_hours > 0::numeric AND m.earned_value_contract IS NOT NULL AND COALESCE(m.contract_amount, 0::numeric) > 0::numeric THEN round(round(100::numeric * m.earned_value_contract / m.contract_amount, 1) / NULLIF(round(100::numeric * m.actual_hours / m.planned_hours, 1), 0::numeric), 2)
            ELSE NULL::numeric
        END) AS exec_signal,
    a.acts_due,
    a.acts_done,
    a.acts_plan_idx,
    archi_flow_idx_signal(a.acts_plan_idx) AS acts_plan_signal,
        CASE
            WHEN COALESCE(m.planned_hours, 0::numeric) > 0::numeric AND m.actual_hours IS NOT NULL AND m.etc_forecast_total_hours IS NOT NULL THEN round(100::numeric * round(m.etc_forecast_total_hours - round(m.planned_hours - m.actual_hours, 1), 1) / m.planned_hours, 1)
            ELSE NULL::numeric
        END AS etc_gap_pct_bac,
    ( SELECT jsonb_object_agg(s.key, archi_vac_signal(((s.value ->> 'etc_forecast_hours'::text)::numeric) - (((s.value ->> 'etc_plan_hours'::text)::numeric) - COALESCE((s.value ->> 'actual_hours_live'::text)::numeric, 0::numeric)), (s.value ->> 'etc_plan_hours'::text)::numeric)) AS jsonb_object_agg
           FROM jsonb_each(m.stage_data) s(key, value)
          WHERE (s.key = ANY (ARRAY['МБР'::text, 'ЕП'::text, 'П'::text, 'Р'::text])) AND (s.value ->> 'etc_forecast_hours'::text) IS NOT NULL AND COALESCE((s.value ->> 'etc_plan_hours'::text)::numeric, 0::numeric) > 0::numeric) AS stage_etc_signal
   FROM project_metrics m
     CROSS JOIN LATERAL archi_acts_plan(m.project_id, COALESCE((m.data_updated_at AT TIME ZONE 'Europe/Kyiv'::text)::date, CURRENT_DATE)) a(acts_due, acts_done, acts_plan_idx);

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
                             tot AS (SELECT COALESCE(sum(h), 0) AS act_h, COALESCE(sum(cost), 0) AS team_cost FROM hrs),
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
                                                                                                                   SELECT m.profitability_plan_pct AS rpp, m.contract_amount, m.bac, m.planned_hours, m.real_rate_team_hour AS rate,
                                                                                                                            GREATEST(COALESCE(m.cost_plan_subcontract, 0) - sub.sub_paid, 0) AS mtc_sub,
                                                                                                                                     round(tot.team_cost + sub.sub_paid, 2) AS actual_cost, tot.act_h, agg.etc_total, agg.pct_complete, agg.plan_all,
                                                                                                                                              CASE WHEN m.planned_hours IS NOT NULL THEN round(m.planned_hours - tot.act_h, 1) END AS etc_fact
                                                                                                                                                FROM m CROSS JOIN tot CROSS JOIN sub CROSS JOIN agg
                                                                                                                                                )
                                                                                                                                                SELECT f.rpp,
                                                                                                                                                       round((f.contract_amount - round(f.actual_cost + f.etc_total * f.rate + f.mtc_sub, 2)) / NULLIF(f.contract_amount, 0) * 100, 1),
                                                                                                                                                              CASE WHEN COALESCE(f.planned_hours, 0) > 0 AND f.etc_total IS NOT NULL THEN round((f.act_h + f.etc_total) / f.planned_hours * 1000) / 10 END,
                                                                                                                                                                     round(round(f.bac * f.pct_complete, 2) / NULLIF(f.actual_cost, 0), 4),
                                                                                                                                                                            f.plan_all,
                                                                                                                                                                                   f.etc_fact,
                                                                                                                                                                                          f.etc_total,
                                                                                                                                                                                                 CASE WHEN f.etc_total IS NOT NULL AND f.etc_fact IS NOT NULL THEN round(f.etc_total - f.etc_fact, 1) END,
                                                                                                                                                                                                        public.archi_etc_gap_signal(f.etc_fact, f.etc_total)
                                                                                                                                                                                                        FROM f;
                                                                                                                                                                                                        $function$
;

CREATE OR REPLACE FUNCTION public.archi_snapshot_evm(p_project text, p_week date, p_rd jsonb, p_et jsonb)
 RETURNS TABLE(spent_pct numeric, ready_pm_pct numeric, ready_fc_pct numeric, ready_gap_pp numeric, ready_gap_signal text, eff_hours_idx numeric, eff_signal text, acts_to_ev numeric, paid_to_acts numeric)
 LANGUAGE sql
 STABLE
AS $function$
WITH m AS (
  SELECT * FROM public.project_metrics WHERE project_id = p_project AND COALESCE(contract_type, 'stages') = 'stages'
),
st AS (SELECT unnest(ARRAY['МБР','ЕП','П','Р']) AS s),
tot AS (
  SELECT COALESCE(sum(t."години"), 0) AS act_h FROM public.time_log t
  WHERE t.project_id = p_project AND t."статус" = 'confirmed' AND t."дата" <= p_week + 6
),
mon AS (
  SELECT COALESCE(sum("сума") FILTER (WHERE "тип" = 'акт_підписаний'), 0) AS acts,
         COALESCE(sum("сума") FILTER (WHERE "тип" = 'надходження_від_замовника'), 0) AS received
  FROM public.money_log
  WHERE project_id = p_project AND "статус" = 'confirmed' AND "дата" <= p_week + 6
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
         CASE WHEN count(rd_f) = 4 AND sum(plan_h) > 0 THEN sum(rd_f / 100 * plan_h) / sum(plan_h) END AS pct_complete
  FROM ps
),
g AS (
  SELECT m.planned_hours, m.contract_amount, tot.act_h, agg.etc_total, agg.pct_complete, mon.acts, mon.received,
         CASE WHEN COALESCE(m.planned_hours, 0) > 0 THEN round(100 * tot.act_h / m.planned_hours, 1) END AS spent_pct,
         CASE WHEN agg.pct_complete IS NOT NULL THEN round(100 * agg.pct_complete, 1) END AS ready_pm_pct,
         CASE WHEN agg.etc_total IS NOT NULL AND tot.act_h + agg.etc_total > 0 THEN round(100 * tot.act_h / (tot.act_h + agg.etc_total), 1) END AS ready_fc_pct,
         CASE WHEN COALESCE(m.planned_hours, 0) > 0 AND agg.etc_total IS NOT NULL AND tot.act_h + agg.etc_total > 0 THEN round(m.planned_hours / (tot.act_h + agg.etc_total), 2) END AS eff_idx
  FROM m CROSS JOIN tot CROSS JOIN mon CROSS JOIN agg
)
SELECT g.spent_pct,
       g.ready_pm_pct,
       g.ready_fc_pct,
       CASE WHEN g.ready_pm_pct IS NOT NULL AND g.ready_fc_pct IS NOT NULL THEN round(g.ready_pm_pct - g.ready_fc_pct, 1) END,
       public.archi_ready_gap_signal(CASE WHEN g.ready_pm_pct IS NOT NULL AND g.ready_fc_pct IS NOT NULL THEN round(g.ready_pm_pct - g.ready_fc_pct, 1) END),
       g.eff_idx,
       public.archi_idx_signal(g.eff_idx),
       CASE WHEN g.pct_complete IS NOT NULL AND g.contract_amount > 0 AND g.pct_complete > 0 THEN round(g.acts / (g.contract_amount * g.pct_complete), 2) END,
       CASE WHEN g.acts > 0 THEN round(g.received / g.acts, 2) END
FROM g;
$function$
;
