-- ARCHI 20.10.2026: розрив ETC (Δ = ETC_прогноз − ETC_факт) і його колір — єдине обчислення в SQL
-- (правило S-04, пороги etc_yellow / etc_red з archi_thresholds). Запускати ОДНИМ запуском.
-- Дані не змінюються, нових таблиць немає. Відкат: повернути попередні версії з
-- sql/2026-10-20_snapshot_history_view.sql і sql/2026-10-18_report_today_view.sql, потім DROP FUNCTION public.archi_etc_gap_signal(numeric,numeric);

CREATE OR REPLACE FUNCTION public.archi_etc_gap_signal(p_fact numeric, p_forecast numeric) RETURNS text
LANGUAGE sql STABLE AS $$
SELECT CASE
  WHEN p_fact IS NULL OR p_forecast IS NULL THEN NULL
  WHEN p_fact <= 0 THEN CASE WHEN p_forecast > 0 THEN 'red' ELSE 'green' END
  WHEN p_forecast - p_fact > p_fact * COALESCE((SELECT value FROM public.archi_thresholds WHERE key = 'etc_red'), 0.10) THEN 'red'
  WHEN p_forecast - p_fact > p_fact * COALESCE((SELECT value FROM public.archi_thresholds WHERE key = 'etc_yellow'), 0.05) THEN 'yellow'
  ELSE 'green' END
$$;

DROP VIEW IF EXISTS public.archi_snapshot_history;
DROP FUNCTION IF EXISTS public.archi_snapshot_metrics(text, date, jsonb, jsonb);

CREATE FUNCTION public.archi_snapshot_metrics(p_project text, p_week date, p_rd jsonb, p_et jsonb)
RETURNS TABLE(rent_plan_pct numeric, rent_forecast_pct numeric, eac_hours_pct numeric, cpi numeric, etc_plan_hours numeric, etc_fact_hours numeric, etc_forecast_hours numeric, etc_gap_hours numeric, etc_gap_signal text)
LANGUAGE sql STABLE AS $$
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
$$;

CREATE VIEW public.archi_snapshot_history AS
SELECT s.project_id, s.week_start,
       x.rent_plan_pct, x.rent_forecast_pct, x.eac_hours_pct, x.cpi, x.etc_plan_hours, x.etc_fact_hours,
       x.etc_forecast_hours, x.etc_gap_hours, x.etc_gap_signal
FROM public.wr_weekly_snapshots s
CROSS JOIN LATERAL public.archi_snapshot_metrics(s.project_id, s.week_start, s."готовність_pct", s."залишок_прогноз_по_стадіях") x;

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
        etc_forecast_total_hours) AS etc_gap_signal
   FROM project_metrics m;
