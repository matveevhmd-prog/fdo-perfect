-- УВАГА 22.10.2026: тексти вʼю archi_snapshot_history / archi_report_today та функцій archi_idx_signal / archi_ready_gap_signal в цьому файлі ЗАСТАРІЛІ — чинні версії в sql/2026-10-21_deviation_colors2.sql і sql/2026-10-22_color_direction.sql.
-- ARCHI 21.10.2026: ланцюжок готовності (EVM, FORMULAS §0, E-01…E-07) — єдине обчислення в SQL.
-- Додає в archi_report_today та archi_snapshot_history: spent_pct, ready_pm_pct, ready_fc_pct, ready_gap_pp, ready_gap_signal,
-- eff_hours_idx, eff_signal, acts_to_ev, paid_to_acts. Пороги: readiness_gap_pp (20 п.п.), cpi_yellow / cpi_red з archi_thresholds.
-- Дані не змінюються. Відкат: повернути sql/2026-10-20_snapshot_history_view.sql + sql/2026-10-20_etc_gap_signal.sql, DROP FUNCTION archi_idx_signal, archi_ready_gap_signal.

CREATE OR REPLACE FUNCTION public.archi_idx_signal(p numeric) RETURNS text
LANGUAGE sql STABLE AS $$
SELECT CASE
  WHEN p IS NULL THEN NULL
  WHEN p < COALESCE((SELECT value FROM public.archi_thresholds WHERE key = 'cpi_red'), 0.85) THEN 'red'
  WHEN p < COALESCE((SELECT value FROM public.archi_thresholds WHERE key = 'cpi_yellow'), 0.95) THEN 'yellow'
  ELSE 'green' END
$$;

CREATE OR REPLACE FUNCTION public.archi_ready_gap_signal(p_pp numeric) RETURNS text
LANGUAGE sql STABLE AS $$
SELECT CASE
  WHEN p_pp IS NULL THEN NULL
  WHEN p_pp >= COALESCE((SELECT value FROM public.archi_thresholds WHERE key = 'readiness_gap_pp'), 20) THEN 'yellow'
  ELSE 'green' END
$$;

CREATE FUNCTION public.archi_snapshot_evm(p_project text, p_week date, p_rd jsonb, p_et jsonb)
RETURNS TABLE(spent_pct numeric, ready_pm_pct numeric, ready_fc_pct numeric, ready_gap_pp numeric, ready_gap_signal text,
              eff_hours_idx numeric, eff_signal text, acts_to_ev numeric, paid_to_acts numeric)
LANGUAGE sql STABLE AS $$
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
$$;

CREATE OR REPLACE VIEW public.archi_snapshot_history AS
SELECT s.project_id, s.week_start,
       x.rent_plan_pct, x.rent_forecast_pct, x.eac_hours_pct, x.cpi, x.etc_plan_hours, x.etc_fact_hours,
       x.etc_forecast_hours, x.etc_gap_hours, x.etc_gap_signal,
       e.spent_pct, e.ready_pm_pct, e.ready_fc_pct, e.ready_gap_pp, e.ready_gap_signal,
       e.eff_hours_idx, e.eff_signal, e.acts_to_ev, e.paid_to_acts
FROM public.wr_weekly_snapshots s
CROSS JOIN LATERAL public.archi_snapshot_metrics(s.project_id, s.week_start, s."готовність_pct", s."залишок_прогноз_по_стадіях") x
CROSS JOIN LATERAL public.archi_snapshot_evm(s.project_id, s.week_start, s."готовність_pct", s."залишок_прогноз_по_стадіях") e;

CREATE OR REPLACE VIEW public.archi_report_today AS
 SELECT project_id,
    data_updated_at,
    profitability_plan_pct AS rent_plan_pct,
    profitability_forecast_pct AS rent_forecast_pct,
    planned_hours,
    actual_hours,
    ( SELECT sum(e.value::numeric) AS sum
           FROM jsonb_each_text(m.etc_plan_by_stage) e(key, value)
          WHERE e.key = ANY (ARRAY['МБР'::text, 'ЕП'::text, 'П'::text, 'Р'::text])) AS etc_plan_hours,
        CASE
            WHEN planned_hours IS NOT NULL AND actual_hours IS NOT NULL THEN round(planned_hours - actual_hours, 1)
            ELSE NULL::numeric
        END AS etc_fact_hours,
    etc_forecast_total_hours AS etc_forecast_hours,
        CASE
            WHEN COALESCE(planned_hours, 0::numeric) > 0::numeric AND actual_hours IS NOT NULL AND etc_forecast_total_hours IS NOT NULL THEN round((actual_hours + etc_forecast_total_hours) / planned_hours * 1000::numeric) / 10::numeric
            ELSE NULL::numeric
        END AS eac_hours_pct,
    cpi_classic_evm AS cpi,
    nearest_act_date AS act_date,
    nearest_act_probability AS act_prob,
    nearest_doc_deadline AS doc_date,
    doc_issuance_probability AS doc_prob,
        CASE
            WHEN planned_hours IS NOT NULL AND actual_hours IS NOT NULL AND etc_forecast_total_hours IS NOT NULL THEN round(etc_forecast_total_hours - round(planned_hours - actual_hours, 1), 1)
            ELSE NULL::numeric
        END AS etc_gap_hours,
    public.archi_etc_gap_signal(
        CASE WHEN planned_hours IS NOT NULL AND actual_hours IS NOT NULL THEN round(planned_hours - actual_hours, 1) END,
        etc_forecast_total_hours) AS etc_gap_signal,
    CASE WHEN COALESCE(planned_hours, 0) > 0 AND actual_hours IS NOT NULL THEN round(100 * actual_hours / planned_hours, 1) END AS spent_pct,
    CASE WHEN earned_value_contract IS NOT NULL AND COALESCE(contract_amount, 0) > 0 THEN round(100 * earned_value_contract / contract_amount, 1) END AS ready_pm_pct,
    CASE WHEN etc_forecast_total_hours IS NOT NULL AND actual_hours IS NOT NULL AND actual_hours + etc_forecast_total_hours > 0 THEN round(100 * actual_hours / (actual_hours + etc_forecast_total_hours), 1) END AS ready_fc_pct,
    CASE WHEN earned_value_contract IS NOT NULL AND COALESCE(contract_amount, 0) > 0 AND etc_forecast_total_hours IS NOT NULL AND actual_hours IS NOT NULL AND actual_hours + etc_forecast_total_hours > 0
         THEN round(round(100 * earned_value_contract / contract_amount, 1) - round(100 * actual_hours / (actual_hours + etc_forecast_total_hours), 1), 1) END AS ready_gap_pp,
    public.archi_ready_gap_signal(
        CASE WHEN earned_value_contract IS NOT NULL AND COALESCE(contract_amount, 0) > 0 AND etc_forecast_total_hours IS NOT NULL AND actual_hours IS NOT NULL AND actual_hours + etc_forecast_total_hours > 0
             THEN round(round(100 * earned_value_contract / contract_amount, 1) - round(100 * actual_hours / (actual_hours + etc_forecast_total_hours), 1), 1) END) AS ready_gap_signal,
    CASE WHEN COALESCE(planned_hours, 0) > 0 AND etc_forecast_total_hours IS NOT NULL AND actual_hours IS NOT NULL AND actual_hours + etc_forecast_total_hours > 0 THEN round(planned_hours / (actual_hours + etc_forecast_total_hours), 2) END AS eff_hours_idx,
    public.archi_idx_signal(
        CASE WHEN COALESCE(planned_hours, 0) > 0 AND etc_forecast_total_hours IS NOT NULL AND actual_hours IS NOT NULL AND actual_hours + etc_forecast_total_hours > 0 THEN round(planned_hours / (actual_hours + etc_forecast_total_hours), 2) END) AS eff_signal,
    CASE WHEN earned_value_contract > 0 THEN round(acts_amount / earned_value_contract, 2) END AS acts_to_ev,
    CASE WHEN acts_amount > 0 THEN round(money_received / acts_amount, 2) END AS paid_to_acts
   FROM project_metrics m;
